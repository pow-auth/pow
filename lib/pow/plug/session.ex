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

    * `:session_key` session key name
    * `:session_store` credentials cache store to use
    * `:cache_store_backend` backend key value store to use
    * `:session_ttl_renewal` the ttl until trigger renewal of session
  """
  use Pow.Plug.Base

  alias Plug.Conn
  alias Pow.{Config, Store.Backend.EtsCache, Store.CredentialsCache}

  @session_ttl_renewal :timer.minutes(15)

  @spec fetch(Conn.t(), Config.t()) :: {Conn.t(), map() | nil}
  def fetch(conn, config) do
    conn
    |> Conn.fetch_session()
    |> get_session(config)
    |> handled_fetched_value(conn, config)
  end

  @spec create(Conn.t(), map(), Config.t()) :: {Conn.t(), map()}
  def create(conn, user, config) do
    key                   = UUID.uuid1()
    session_key           = session_key(config)
    {store, store_config} = store(config)
    value                 = session_value(user)
    conn                  = delete(conn, config)

    store.put(store_config, key, value)

    conn =
      conn
      |> delete(config)
      |> Conn.put_session(session_key, key)

    {conn, user}
  end

  @spec delete(Conn.t(), Config.t()) :: Conn.t()
  def delete(conn, config) do
    key                   = Conn.get_session(conn, session_key(config))
    {store, store_config} = store(config)
    session_key           = session_key(config)

    store.delete(store_config, key)

    Conn.delete_session(conn, session_key)
  end

  defp get_session(conn, config) do
    key = Conn.get_session(conn, session_key(config))
    {store, store_config} = store(config)

    store.get(store_config, key)
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
    (inserted_at + ttl) < timestamp()
  end

  defp session_key(config) do
    Config.get(config, :session_key, "auth")
  end

  def session_value(user), do: {user, timestamp()}

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
