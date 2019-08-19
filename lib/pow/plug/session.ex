defmodule Pow.Plug.Session do
  @moduledoc """
  This plug will handle user authorization using session.

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

  See `do_fetch/2` for more.
  """
  @impl true
  @spec fetch(Conn.t(), Config.t()) :: {Conn.t(), map() | nil}
  def fetch(conn, config) do
    conn                  = Conn.fetch_session(conn)
    key                   = Conn.get_session(conn, session_key(config))
    {store, store_config} = store(config)

    store_config
    |> store.get(key)
    |> handled_fetched_value(conn, config)
  end

  @doc """
  Create new session with a randomly generated unique session id.

  This will store the unique session id with user credentials in the
  credentials cache. The session id will be stored in the connection with
  `Plug.Conn.put_session/3`. Any existing sessions will be deleted first with
  `delete/2`.

  The unique session id will be prepended by the `:otp_app` configuration
  value, if present.

  See `do_create/3` for more.
  """
  @impl true
  @spec create(Conn.t(), map(), Config.t()) :: {Conn.t(), map()}
  def create(conn, user, config) do
    conn                  = Conn.fetch_session(conn)
    key                   = session_id(config)
    session_key           = session_key(config)
    {store, store_config} = store(config)
    value                 = session_value(user)

    store.put(store_config, key, value)

    conn =
      conn
      |> delete(config)
      |> Conn.put_session(session_key, key)

    {conn, user}
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

  defp handled_fetched_value(:not_found, conn, _config), do: {conn, nil}
  defp handled_fetched_value({user, inserted_at}, conn, config) do
    case session_stale?(inserted_at, config) do
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

  defp session_value(user), do: {user, timestamp()}

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
