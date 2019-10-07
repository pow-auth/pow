defmodule PowPersistentSession.Plug.Cookie do
  @moduledoc """
  This plug will handle persistent user sessions with cookies.

  By default, the cookie will expire after 30 days. The cookie expiration will
  be renewed on every request. The token in the cookie can only be used once to
  create a session.

  If an assigned private `:pow_session_metadata` key exists in the conn with a
  keyword list containing a `:fingerprint` key, that fingerprint value will be
  set along with the user id as the persistent session value as
  `{user_id, session_fingerprint: fingerprint}`.

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

    * `:persistent_session_cookie_key` - session key name. This defaults to
      "persistent_session_cookie". If `:otp_app` is used it'll automatically
      prepend the key with the `:otp_app` value.

    * `:persistent_session_ttl` - used for both backend store and max age for
      cookie. See `PowPersistentSession.Plug.Base` for more.
  """
  use PowPersistentSession.Plug.Base

  alias Plug.Conn
  alias Pow.{Config, Plug, UUID}

  @cookie_key "persistent_session_cookie"

  @doc """
  Sets a persistent session cookie with an auto generated token.

  The token is set as a key in the persistent session cache with the id fetched
  from the struct.

  If an assigned private `:pow_session_metadata` key exists in the conn with a
  keyword list containing a `:fingerprint` value, then that value will be set
  as the `:session_fingerprint` in the metadata. The value will look like:
  `{user_id, session_fingerprint: fingerprint}`

  The unique cookie id will be prepended by the `:otp_app` configuration
  value, if present.
  """
  @spec create(Conn.t(), map(), Config.t()) :: Conn.t()
  def create(conn, user, config) do
    {store, store_config} = store(config)
    cookie_key            = cookie_key(config)
    key                   = cookie_id(config)
    value                 = persistent_session_value(conn, user)
    opts                  = session_opts(config)

    store.put(store_config, key, value)
    Conn.put_resp_cookie(conn, cookie_key, key, opts)
  end

  defp persistent_session_value(conn, %{id: id}) do
    conn.private
    |> Map.get(:pow_session_metadata, [])
    |> Keyword.get(:fingerprint)
    |> case do
      nil         -> id
      fingerprint -> {id, session_fingerprint: fingerprint}
    end
  end

  @doc """
  Expires the persistent session cookie.

  If a persistent session cookie exists it'll be expired, and the token in
  the persistent session cache will be deleted.
  """
  @spec delete(Conn.t(), Config.t()) :: Conn.t()
  def delete(conn, config) do
    cookie_key = cookie_key(config)

    case conn.req_cookies[cookie_key] do
      nil    -> conn
      key_id -> do_delete(conn, cookie_key, key_id, config)
    end
  end

  defp do_delete(conn, cookie_key, key_id, config) do
    {store, store_config} = store(config)
    value                 = ""
    opts                  = [max_age: -1, path: "/"]

    store.delete(store_config, key_id)
    Conn.put_resp_cookie(conn, cookie_key, value, opts)
  end

  @doc """
  Authenticates a user with the persistent session cookie.

  If a persistent session cookie exists, it'll fetch the credentials from the
  persistent session cache, and create a new session and persistent session
  cookie. The old persistent session cookie and session cache credentials will
  be removed.

  If a `:session_fingerprint` is fetched from the persistent session metadata,
  it'll be assigned to the private `:pow_session_metadata` key in the conn as
  `:fingerprint`.

  The cookie expiration will automatically be renewed on every request.
  """
  @spec authenticate(Conn.t(), Config.t()) :: Conn.t()
  def authenticate(conn, config) do
    user = Plug.current_user(conn, config)

    conn
    |> Conn.fetch_cookies()
    |> maybe_authenticate(user, config)
    |> maybe_renew(config)
  end

  defp maybe_authenticate(conn, nil, config) do
    cookie_key = cookie_key(config)

    case conn.req_cookies[cookie_key] do
      nil    -> conn
      key_id -> do_authenticate(conn, key_id, config)
    end
  end
  defp maybe_authenticate(conn, _user, _config), do: conn

  defp do_authenticate(conn, key_id, config) do
    {store, store_config} = store(config)
    res                   = store.get(store_config, key_id)
    plug                  = Plug.get_plug(config)
    conn                  = delete(conn, config)

    case res do
      :not_found -> conn
      res        -> fetch_and_auth_user(conn, res, plug, config)
    end
  end

  defp fetch_and_auth_user(conn, {user_id, metadata}, plug, config) do
    conn = update_session_metadata_with_fingerprint(conn, metadata)

    [id: user_id]
    |> Pow.Operations.get_by(config)
    |> case do
      nil ->
        conn

      user ->
        conn
        |> create(user, config)
        |> plug.do_create(user, config)
    end
  end
  defp fetch_and_auth_user(conn, user_id, plug, config),
    do: fetch_and_auth_user(conn, {user_id, []}, plug, config)

  defp update_session_metadata_with_fingerprint(conn, metadata) do
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

  defp maybe_renew(conn, config) do
    cookie_key  = cookie_key(config)

    case conn.resp_cookies[cookie_key] do
      nil  -> renew(conn, cookie_key, config)
      _any -> conn
    end
  end

  defp renew(conn, cookie_key, config) do
    opts = session_opts(config)

    case conn.req_cookies[cookie_key] do
      nil   -> conn
      value -> Conn.put_resp_cookie(conn, cookie_key, value, opts)
    end
  end

  defp cookie_id(config) do
    uuid = UUID.generate()

    Plug.prepend_with_namespace(config, uuid)
  end

  defp cookie_key(config) do
    Config.get(config, :persistent_session_cookie_key, default_cookie_key(config))
  end

  defp default_cookie_key(config) do
    Plug.prepend_with_namespace(config, @cookie_key)
  end

  defp session_opts(config) do
    [max_age: max_age(config), path: "/"]
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
