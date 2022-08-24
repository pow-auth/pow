defmodule Pow.Plug.Session do
  @moduledoc """
  This plug will handle user authorization using session.

  The plug will store user and session metadata in the cache store backend. The
  session metadata has at least an `:inserted_at` and a `:fingerprint` key. The
  `:inserted_at` value is used to determine if the session has to be renewed,
  and is set each time a session is created. The `:fingerprint` will be a random
  unique id and will stay the same if a session is renewed.

  When a session is renewed the old session is deleted and a new created.

  You can add additional metadata to sessions by setting or updated the
  assigned private `:pow_session_metadata` key in the conn. The value has to be
  a keyword list.

  The session id used in the client is signed using `Pow.Plug.sign_token/4` to
  prevent timing attacks.

  ## Example

      @pow_config [
        repo: MyApp.Repo,
        user: MyApp.User,
        current_user_assigns_key: :current_user,
        session_key: "auth",
        credentials_cache_store: {Pow.Store.CredentialsCache,
                                  ttl: :timer.minutes(30),
                                  namespace: "credentials"},
        session_ttl_renewal: :timer.minutes(15),
        cache_store_backend: Pow.Store.Backend.EtsCache,
        users_context: Pow.Ecto.Users
      ]

      # ...

      plug Plug.Session, @session_options
      plug Pow.Plug.Session, @pow_config

  ## Configuration options

    * `:credentials_cache_store` - see `Pow.Plug.Base`.

    * `:cache_store_backend` - see `Pow.Plug.Base`.

    * `:session_key` - session key name, defaults to "auth". If `:otp_app` is
      used it'll automatically prepend the key with the `:otp_app` value.

    * `:session_ttl_renewal` - the ttl in milliseconds to trigger renewal of
      sessions. Defaults to 15 minutes in miliseconds.

  ## Custom metadata

  The assigned private `:pow_session_metadata` key in the conn can be populated
  with custom metadata. This data will be stored in the session metadata when
  the session is created, and fetched in subsequent requests.

  Here's an example of how one could add sign in timestamp, IP, and user agent
  information to the session metadata:

      def append_to_session_metadata(conn) do
        client_ip  = to_string(:inet_parse.ntoa(conn.remote_ip))
        user_agent = get_req_header(conn, "user-agent")

        metadata =
          conn.private
          |> Map.get(:pow_session_metadata, [])
          |> Keyword.put_new(:first_seen_at, DateTime.utc_now())
          |> Keyword.put(:ip, client_ip)
          |> Keyword.put(:user_agent, user_agent)

        Plug.Conn.put_private(conn, :pow_session_metadata, metadata)
      end

  The `:first_seen_at` will only be set if it doesn't already exist in the
  session metadata, while `:ip` and `:user_agent` will be updated each time the
  session is created.

  The function should be called after `Pow.Plug.Session.call/2` has been called
  to ensure that the metadata, if any, has been fetched.

  ## Session expiration

  `Pow.Store.CredentialsCache` will, by default, invalidate any session token
  30 minutes after it has been generated. To keep sessions alive the
  `:session_ttl_renewal` option is used to determine when a session token
  becomes stale and a new session ID has to be generated for the user (deleting
  the previous one in the process).

  If `:session_ttl_renewal` is set to zero, a new session token will be
  generated on every request.

  To change the amount of time a session can be alive, both the TTL for
  `Pow.Store.CredentialsCache` and `:session_ttl_renewal` option should be
  changed:

      plug Pow.Plug.Session, otp_app: :my_app,
        session_ttl_renewal: :timer.minutes(1),
        credentials_cache_store: {Pow.Store.CredentialsCache, ttl: :timer.minutes(15)}

  In the above, a new session token will be generated when a request occurs
  more than a minute after the current session token was generated. The
  session is invalidated if there is no request for the next 14 minutes.

  There are no absolute session timeout; sessions can be kept alive
  indefinitely.
  """
  use Pow.Plug.Base

  alias Plug.Conn
  alias Pow.{Config, Plug, UUID}

  @session_key "auth"
  @session_ttl_renewal :timer.minutes(15)

  @doc """
  Fetches session from credentials cache.

  This will fetch a session from the credentials cache with the session id
  fetched through `Plug.Conn.get_session/2` session. If the credentials are
  stale (timestamp is older than the `:session_ttl_renewal` value), a global
  lock will be set, and the session will be regenerated with `create/3`.
  Nothing happens if setting the lock failed.

  The metadata of the session will be assigned as a private
  `:pow_session_metadata` key in the conn so it may be used in `create/3`.

  If the credentials cache returns a `nil` value the session will be
  immediately deleted as it means the context function could not find the
  associated user.

  The session id will be decoded and verified with `Pow.Plug.verify_token/4`.

  See `do_fetch/2` for more.
  """
  @impl true
  @spec fetch(Conn.t(), Config.t()) :: {Conn.t(), map() | nil}
  def fetch(conn, config) do
    case client_store_fetch(conn, config) do
      {nil, conn}        -> {conn, nil}
      {session_id, conn} -> fetch(conn, session_id, config)
    end
  end

  defp fetch(conn, session_id, config) do
    {store, store_config} = store(config)

    {session_id, store.get(store_config, session_id)}
    |> convert_old_session_value()
    |> handle_fetched_session_value(conn, config)
  end

  @doc """
  Create new session with a randomly generated unique session id.

  This will store the unique session id with user credentials in the
  credentials cache. The session id will be stored in the connection with
  `Plug.Conn.put_session/3`. Any existing sessions will be deleted first with
  `delete/2`.

  The unique session id will be prepended by the `:otp_app` configuration
  value, if present.

  If an assigned private `:pow_session_metadata` key exists in the conn, it'll
  be passed on as the metadata for the session. However the `:inserted_at` value
  will always be overridden. If no `:fingerprint` exists in the metadata a
  random UUID value will be generated as its value.

  The session id will be signed for public consumption with
  `Pow.Plug.sign_token/4`.

  See `do_create/3` for more.
  """
  @impl true
  @spec create(Conn.t(), map(), Config.t()) :: {Conn.t(), map()}
  def create(conn, user, config) do
    metadata         = Map.get(conn.private, :pow_session_metadata, [])
    {user, metadata} = session_value(user, metadata)

    conn =
      conn
      |> delete(config)
      |> before_send_create({user, metadata}, config)
      |> Conn.put_private(:pow_session_metadata, metadata)

    {conn, user}
  end

  defp session_value(user, metadata) do
    metadata =
      metadata
      |> Keyword.put_new(:fingerprint, gen_fingerprint())
      |> Keyword.put(:inserted_at, timestamp())

    {user, metadata}
  end

  defp gen_fingerprint(), do: UUID.generate()

  defp before_send_create(conn, value, config) do
    {store, store_config} = store(config)
    session_id            = gen_session_id(config)

    register_before_send(conn, fn conn ->
      store.put(store_config, session_id, value)

      client_store_put(conn, session_id, config)
    end)
  end

  @doc """
  Delete an existing session in the credentials cache.

  This will delete a session in the credentials cache with the session id
  fetched through `Plug.Conn.get_session/2`. The session in the connection is
  deleted too with `Plug.Conn.delete_session/2`.

  See `do_delete/2` for more.
  """
  @impl true
  @spec delete(Conn.t(), Config.t()) :: Conn.t()
  def delete(conn, config), do: before_send_delete(conn, config)

  defp before_send_delete(conn, config) do
    {store, store_config} = store(config)

    register_before_send(conn, fn conn ->
      case client_store_fetch(conn, config) do
        {nil, conn} ->
          conn

        {session_id, conn} ->
          store.delete(store_config, session_id)

          client_store_delete(conn, config)
      end
    end)
  end

  # TODO: Remove by 1.1.0
  defp convert_old_session_value({session_id, {user, timestamp}}) when is_number(timestamp), do: {session_id, {user, inserted_at: timestamp}}
  defp convert_old_session_value(any), do: any

  defp handle_fetched_session_value({_session_id, :not_found}, conn, _config), do: {conn, nil}
  defp handle_fetched_session_value({session_id, nil}, conn, config) do
    {store, store_config} = store(config)

    store.delete(store_config, session_id)

    {conn, nil}
  end
  defp handle_fetched_session_value({session_id, {user, metadata}}, conn, config) when is_list(metadata) do
    conn
    |> Conn.put_private(:pow_session_metadata, metadata)
    |> renew_stale_session(session_id, user, metadata, config)
  end

  defp renew_stale_session(conn, session_id, user, metadata, config) do
    metadata
    |> Keyword.get(:inserted_at)
    |> session_stale?(config)
    |> case do
      true  -> lock_create(conn, session_id, user, config)
      false -> {conn, user}
    end
  end

  defp lock_create(conn, session_id, user, config) do
    id    = {[__MODULE__, session_id], self()}
    nodes = Node.list() ++ [node()]

    case :global.set_lock(id, nodes, 0) do
      true ->
        {conn, user} = create(conn, user, config)

        conn = register_before_send(conn, fn conn ->
          :global.del_lock(id, nodes)

          conn
        end)

        {conn, user}

      false ->
        {conn, user}
    end
  end

  defp session_stale?(inserted_at, config) do
    ttl = Config.get(config, :session_ttl_renewal, @session_ttl_renewal)
    session_stale?(inserted_at, config, ttl)
  end
  defp session_stale?(_inserted_at, _config, nil), do: false
  defp session_stale?(inserted_at, _config, ttl) do
    inserted_at + ttl < timestamp()
  end

  defp gen_session_id(config) do
    uuid = UUID.generate()

    Plug.prepend_with_namespace(config, uuid)
  end

  defp session_key(config) do
    Config.get(config, :session_key, default_session_key(config))
  end

  defp default_session_key(config) do
    Plug.prepend_with_namespace(config, @session_key)
  end

  defp timestamp, do: :os.system_time(:millisecond)

  defp client_store_fetch(conn, config) do
    conn = Conn.fetch_session(conn)

    with session_id when is_binary(session_id) <- Conn.get_session(conn, session_key(config)),
         {:ok, session_id}                     <- Plug.verify_token(conn, signing_salt(), session_id) do
      {session_id, conn}
    else
      _any -> {nil, conn}
    end
  end

  defp signing_salt(), do: Atom.to_string(__MODULE__)

  defp client_store_put(conn, session_id, config) do
    signed_session_id = Plug.sign_token(conn, signing_salt(), session_id, config)

    conn
    |> Conn.fetch_session()
    |> Conn.put_session(session_key(config), signed_session_id)
    |> Conn.configure_session(renew: true)
  end

  defp client_store_delete(conn, config) do
    conn
    |> Conn.fetch_session()
    |> Conn.delete_session(session_key(config))
  end
end
