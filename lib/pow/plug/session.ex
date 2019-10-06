defmodule Pow.Plug.Session do
  @moduledoc """
  This plug will handle user authorization using session.

  The plug will store user and metadata in the cache store backend. The
  metadata has a `:inserted_at` and `:fingerprint` key. The `:inserted_at`
  value is used to determine if the session has to be renewed, while the
  `:fingerprint` will remain the same across sessions if the session was
  renewed (deleted and created). Otherwise a random unique id will be generated
  as fingerprint.

  You can add additional metadata to sessions by setting the
  `:pow_session_metadata` private key in the conn. The value has to be a
  keyword list.

  ## Example

      plug Plug.Session,
        store: :cookie,
        key: "_my_app_demo_key",
        signing_salt: "secret"

      plug Pow.Plug.Session,
        repo: MyApp.Repo,
        user: MyApp.User,
        current_user_assigns_key: :current_user,
        session_key: "auth",
        session_store: {Pow.Store.CredentialsCache,
                        ttl: :timer.minutes(30),
                        namespace: "credentials"},
        session_ttl_renewal: :timer.minutes(15),
        cache_store_backend: Pow.Store.Backend.EtsCache,
        users_context: Pow.Ecto.Users

  ## Configuration options

    * `:session_key` - session key name, defaults to "auth". If `:otp_app` is
      used it'll automatically prepend the key with the `:otp_app` value.

    * `:session_store` - the credentials cache store. This value defaults to
      `{Pow.Store.CredentialsCache, backend: Pow.Store.Backend.EtsCache}`. The
      `Pow.Store.Backend.EtsCache` backend store can be changed with the
      `:cache_store_backend` option.

    * `:cache_store_backend` - the backend cache store. This value defaults to
      `Pow.Store.Backend.EtsCache`.

    * `:session_ttl_renewal` - the ttl in milliseconds to trigger renewal of
      sessions. Defaults to 15 minutes in miliseconds.

  ## Custom metadata

  The `:pow_session_metadata` key in `conn.private` can be populated with custom
  metadata. Here's one way to do it:

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
  fetched metadata, while `:ip` and `:user_agent` will be updated each time the
  session is created/renewed.

  The method should be called after `Pow.Plug.Session.call/2` has been called
  to ensure that the metadata, if any, has been fetched.
  """
  use Pow.Plug.Base

  alias Plug.Conn
  alias Pow.{Config, Plug, Store.Backend.EtsCache, Store.CredentialsCache, UUID}

  @session_key "auth"
  @session_ttl_renewal :timer.minutes(15)

  @doc """
  Fetches session from credentials cache.

  This will fetch a session from the credentials cache with the session id
  fetched through `Plug.Conn.get_session/2` session. If the credentials are
  stale (timestamp is older than the `:session_ttl_renewal` value), the session
  will be regenerated with `create/3`.

  The metadata of the session will be set as the `:pow_session_metadata`
  private key in the conn so it can be used in the renewal process.

  See `do_fetch/2` for more.
  """
  @impl true
  @spec fetch(Conn.t(), Config.t()) :: {Conn.t(), map() | nil}
  def fetch(conn, config) do
    {store, store_config} = store(config)
    conn                  = Conn.fetch_session(conn)
    key                   = Conn.get_session(conn, session_key(config))

    {key, store.get(store_config, key)}
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

  If `:pow_session_metadata` exists as a private key in the conn, it'll be
  passed on as the metadata of the session. If a `:fingerprint` is not set in
  the metadata a new random `:fingerprint` UUID will be generated.

  See `do_create/3` for more.
  """
  @impl true
  @spec create(Conn.t(), map(), Config.t()) :: {Conn.t(), map()}
  def create(conn, user, config) do
    conn                  = Conn.fetch_session(conn)
    {store, store_config} = store(config)
    metadata              = Map.get(conn.private, :pow_session_metadata, [])
    {user, metadata}      = session_value(user, metadata)
    key                   = session_id(config)
    session_key           = session_key(config)

    store.put(store_config, key, {user, metadata})

    conn =
      conn
      |> delete(config)
      |> Conn.put_private(:pow_session_metadata, metadata)
      |> Conn.put_session(session_key, key)

    {conn, user}
  end

  defp session_value(user, metadata) do
    metadata =
      metadata
      |> Keyword.put_new(:fingerprint, UUID.generate())
      |> Keyword.put(:inserted_at, timestamp())

    {user, metadata}
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
  def delete(conn, config) do
    conn                  = Conn.fetch_session(conn)
    key                   = Conn.get_session(conn, session_key(config))
    {store, store_config} = store(config)
    session_key           = session_key(config)

    store.delete(store_config, key)

    Conn.delete_session(conn, session_key)
  end

  # TODO: Remove by 1.1.0
  defp convert_old_session_value({key, {user, timestamp}}) when is_number(timestamp), do: {key, {user, inserted_at: timestamp}}
  defp convert_old_session_value(any), do: any

  defp handle_fetched_session_value({_key, :not_found}, conn, _config), do: {conn, nil}
  defp handle_fetched_session_value({_key, {user, metadata}}, conn, config) when is_list(metadata) do
    conn
    |> Conn.put_private(:pow_session_metadata, metadata)
    |> renew_stale_session(user, metadata, config)
  end

  defp renew_stale_session(conn, user, metadata, config) do
    metadata
    |> Keyword.get(:inserted_at)
    |> session_stale?(config)
    |> case do
      true  -> create(conn, user, config)
      false -> {conn, user}
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

  defp session_id(config) do
    uuid = UUID.generate()

    Plug.prepend_with_namespace(config, uuid)
  end

  defp session_key(config) do
    Config.get(config, :session_key, default_session_key(config))
  end

  defp default_session_key(config) do
    Plug.prepend_with_namespace(config, @session_key)
  end

  defp store(config) do
    case Config.get(config, :session_store, default_store(config)) do
      {store, store_config} -> {store, store_config}
      store                 -> {store, []}
    end
  end

  defp default_store(config) do
    backend = Config.get(config, :cache_store_backend, EtsCache)

    {CredentialsCache, [backend: backend]}
  end

  defp timestamp, do: :os.system_time(:millisecond)
end
