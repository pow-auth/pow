defmodule PowPersistentSession.Plug.Cookie do
  @moduledoc """
  This plug will handle persistent user sessions with cookies.

  The cookie and token will expire after 30 days. The token in the cookie can
  only be used once to create a session.

  If an assigned private `:pow_session_metadata` key exists in the conn with a
  keyword list containing a `:fingerprint` key, that fingerprint value will be
  set along with the user as the persistent session value as
  `{user, session_metadata: [fingerprint: fingerprint]}`.

  The token used in the client is signed using `Pow.Plug.sign_token/4` to
  prevent timing attacks.

  ## Example

    defmodule MyAppWeb.Endpoint do
      # ...

      plug Pow.Plug.Session, otp_app: :my_app
      plug PowPersistentSession.Plug.Cookie
      #...
    end

  ## Configuration options

    * `:persistent_session_store` - see `PowPersistentSession.Plug.Base`

    * `:cache_store_backend` - see `PowPersistentSession.Plug.Base`

    * `:persistent_session_cookie_key` - cookie key name. This defaults to
      "persistent_session". If `:otp_app` is used it'll automatically prepend
      the key with the `:otp_app` value.

    * `:persistent_session_ttl` - used for both backend store and max age for
      cookie. See `PowPersistentSession.Plug.Base` for more.

    * `:persistent_session_cookie_opts` - keyword list of cookie options, see
      `Plug.Conn.put_resp_cookie/4` for options. The default options are
      `[max_age: max_age, path: "/"]` where `:max_age` is the value defined in
      `:persistent_session_ttl`.

  ## Custom metadata

  You can assign a private `:pow_persistent_session_metadata` key in the conn
  with custom metadata as a keyword list. The only current use this has is to
  set `:session_metadata` that'll be passed on as `:pow_session_metadata` for
  new session generation.

        session_metadata =
          conn.private
          |> Map.get(:pow_session_metadata, [])
          |> Keyword.take([:first_seen_at])

        Plug.Conn.put_private(conn, :pow_persistent_session_metadata, session_metadata: session_metadata)

  This ensure that you are able to keep session metadata consistent between
  browser sessions.

  When a persistent session token is used, the
  `:pow_persistent_session_metadata` assigns key in the conn will be populated
  with a `:session_metadata` keyword list so that the session metadata that was
  pulled from the persistent session can be carried over to the new persistent
  session. `:fingerprint` will always be ignored as to not record the old
  fingerprint.
  """
  use PowPersistentSession.Plug.Base

  alias Plug.Conn
  alias Pow.{Config, Plug, UUID}

  @cookie_key "persistent_session"

  @doc """
  Sets a persistent session cookie with a randomly generated unique token.

  The token is set as a key in the persistent session cache with the id fetched
  from the struct. Any existing persistent session will be deleted first with
  `delete/2`.

  If an assigned private `:pow_session_metadata` key exists in the conn with a
  keyword list containing a `:fingerprint` value, then that value will be set
  in a `:session_metadata` keyword list in the persistent session metadata. The
  value will look like:
  `{user, session_metadata: [fingerprint: fingerprint]}`

  The unique token will be prepended by the `:otp_app` configuration value, if
  present.

  The token will be signed for public consumption with `Pow.Plug.sign_token/4`.
  """
  @spec create(Conn.t(), map(), Config.t()) :: Conn.t()
  def create(conn, user, config) do
    conn
    |> delete(config)
    |> before_send_create(user, config)
  end

  defp before_send_create(conn, user, config) do
    {store, store_config} = store(config)
    token                 = gen_token(config)
    value                 = persistent_session_value(conn, user)

    register_before_send(conn, fn conn ->
      store.put(store_config, token, value)

      client_store_put(conn, token, config)
    end)
  end

  defp persistent_session_value(conn, user) do
    metadata =
      conn.private
      |> Map.get(:pow_persistent_session_metadata, [])
      |> maybe_put_fingerprint_in_session_metadata(conn)

    {user, metadata}
  end

  defp maybe_put_fingerprint_in_session_metadata(metadata, conn) do
    conn.private
    |> Map.get(:pow_session_metadata, [])
    |> Keyword.get(:fingerprint)
    |> case do
      nil ->
        metadata

      fingerprint ->
        session_metadata =
          metadata
          |> Keyword.get(:session_metadata, [])
          |> Keyword.put_new(:fingerprint, fingerprint)

        Keyword.put(metadata, :session_metadata, session_metadata)
    end
  end

  @doc """
  Expires the persistent session.

  If a persistent session cookie exists the token in the persistent session
  cache will be deleted, and cookie deleted with
  `Plug.Conn.delete_resp_cookie/3`.
  """
  @spec delete(Conn.t(), Config.t()) :: Conn.t()
  def delete(conn, config), do: before_send_delete(conn, config)

  defp before_send_delete(conn, config) do
    register_before_send(conn, fn conn ->
      case client_store_fetch(conn, config) do
        {nil, conn} ->
          conn

        {token, conn} ->
          expire_token_in_store(token, config)

          client_store_delete(conn, config)
      end
    end)
  end

  defp expire_token_in_store(token, config) do
    {store, store_config} = store(config)

    store.delete(store_config, token)
  end

  @doc """
  Authenticates a user with the persistent session cookie.

  If a persistent session cookie exists, it'll fetch the credentials from the
  persistent session cache.

  If credentials was fetched successfully, a global lock is set and the token
  in the cache is deleted, a new session is created, and `create/2` is called
  to create a new persistent session cookie. If setting the lock failed, the
  user will fetched will be set for the `conn` with
  `Pow.Plug.assign_current_user/3`.

  If a `:session_metadata` keyword list is fetched from the persistent session
  metadata, all the values will be merged into the private
  `:pow_session_metadata` key in the conn.

  If the persistent session cache returns a `nil` value the persistent session
  will be deleted as it means the context function could not find the
  associated user.

  The persistent session token will be decoded and verified with
  `Pow.Plug.verify_token/4`.
  """
  @spec authenticate(Conn.t(), Config.t()) :: Conn.t()
  def authenticate(conn, config) do
    case client_store_fetch(conn, config) do
      {nil, conn}   -> conn
      {token, conn} -> do_authenticate(conn, token, config)
    end
  end

  defp do_authenticate(conn, token, config) do
    {store, store_config} = store(config)

    case {token, store.get(store_config, token)} do
      {_token, :not_found} ->
        conn

      {token, nil} ->
        expire_token_in_store(token, config)

        conn

      {token, {user, metadata}} ->
        lock_auth_user(conn, token, user, metadata, config)
    end
  end

  defp lock_auth_user(conn, token, user, metadata, config) do
    id    = {[__MODULE__, token], self()}
    nodes = Node.list() ++ [node()]

    case :global.set_lock(id, nodes, 0) do
      true ->
        conn
        |> auth_user(user, metadata, config)
        |> register_before_send(fn conn ->
          :global.del_lock(id, nodes)

          conn
        end)

      false ->
        Plug.assign_current_user(conn, user, config)
    end
  end

  defp auth_user(conn, user, metadata, config) do
    conn
    |> update_persistent_session_metadata(metadata)
    |> update_session_metadata(metadata)
    |> create(user, config)
    |> Plug.create(user, config)
  end

  defp update_persistent_session_metadata(conn, metadata) do
    case Keyword.get(metadata, :session_metadata) do
      nil ->
        conn

      session_metadata ->
        current_metadata =
          conn.private
          |> Map.get(:pow_persistent_session_metadata, [])
          |> Keyword.get(:session_metadata, [])

        metadata =
          session_metadata
          |> Keyword.merge(current_metadata)
          |> Keyword.delete(:fingerprint)

        Conn.put_private(conn, :pow_persistent_session_metadata, session_metadata: metadata)
    end
  end

  defp update_session_metadata(conn, metadata) do
    case Keyword.get(metadata, :session_metadata) do
      nil ->
        fallback_session_fingerprint(conn, metadata)

      session_metadata ->
        metadata = Map.get(conn.private, :pow_session_metadata, [])

        Conn.put_private(conn, :pow_session_metadata, Keyword.merge(session_metadata, metadata))
    end
  end

  # TODO: Remove by 1.1.0
  defp fallback_session_fingerprint(conn, metadata) do
    case Keyword.get(metadata, :session_fingerprint) do
      nil ->
        conn

      fingerprint ->
        metadata =
          conn.private
          |> Map.get(:pow_session_metadata, [])
          |> Keyword.put(:fingerprint, fingerprint)

        Conn.put_private(conn, :pow_session_metadata, metadata)
    end
  end

  defp gen_token(config) do
    uuid = UUID.generate()

    Plug.prepend_with_namespace(config, uuid)
  end

  defp client_store_fetch(conn, config) do
    conn = Conn.fetch_cookies(conn)

    with token when is_binary(token) <- conn.cookies[cookie_key(config)],
         {:ok, token}                <- Plug.verify_token(conn, signing_salt(), token, config) do
      {token, conn}
    else
      _any -> {nil, conn}
    end
  end

  defp signing_salt(), do: Atom.to_string(__MODULE__)

  defp client_store_put(conn, token, config) do
    signed_token = Plug.sign_token(conn, signing_salt(), token, config)

    conn
    |> Conn.fetch_cookies()
    |> Conn.put_resp_cookie(cookie_key(config), signed_token, cookie_opts(config))
  end

  defp client_store_delete(conn, config) do
    conn
    |> Conn.fetch_cookies()
    |> Conn.delete_resp_cookie(cookie_key(config), cookie_opts(config))
  end

  defp cookie_key(config) do
    Config.get(config, :persistent_session_cookie_key, default_cookie_key(config))
  end

  defp default_cookie_key(config) do
    Plug.prepend_with_namespace(config, @cookie_key)
  end

  defp cookie_opts(config) do
    config
    |> Config.get(:persistent_session_cookie_opts, [])
    |> Keyword.put_new(:max_age, max_age(config))
    |> Keyword.put_new(:path, "/")
  end

  defp max_age(config) do
    # TODO: Remove by 1.1.0
    case Config.get(config, :persistent_session_cookie_max_age) do
      nil ->
        config
        |> PowPersistentSession.Plug.Base.ttl()
        |> Integer.floor_div(1000)

      max_age ->
        IO.warn("use of `:persistent_session_cookie_max_age` config value in #{inspect unquote(__MODULE__)} is deprecated, please use `:persistent_session_ttl`")

        max_age
    end
  end
end
