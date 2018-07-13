defmodule Authex.Plug.Session do
  @moduledoc """
  This plug will handle user authorization using session.

  Example:

    plug Plug.Session,
      store: :cookie,
      key: "_my_app_demo_key",
      signing_salt: "secret"

    plug Authex.Plug.Session,
      repo: MyApp.Repo,
      user: MyApp.User,
      current_user_assigns_key: :current_user,
      session_key: "auth",
      session_store: Authex.Store.CredentialsCache,
      credentials_cache_name: "credentials",
      credentials_cache_ttl: :timer.hours(48),
      users_context: Authex.Ecto.Users
  """
  use Authex.Plug.Base

  alias Plug.Conn
  alias Authex.{Config, Plug, Store.CredentialsCache}

  @spec fetch(Conn.t(), Config.t()) :: map() | nil
  def fetch(conn, config) do
    conn
    |> Conn.fetch_session()
    |> get_session(config)
    |> case do
      :not_found -> nil
      user       -> user
    end
  end

  @spec create(Conn.t(), map(), Config.t()) :: Conn.t()
  def create(conn, user, config) do
    key           = UUID.uuid1()
    session_key   = session_key(config)
    store         = store(config)

    delete(conn, config)
    store.put(config, key, user)

    conn
    |> Conn.put_session(session_key, key)
    |> Plug.assign_current_user(user, config)
  end

  @spec delete(Conn.t(), Config.t()) :: Conn.t()
  def delete(conn, config) do
    key         = Conn.get_session(conn, session_key(config))
    store       = store(config)
    session_key = session_key(config)

    store.delete(config, key)

    conn
    |> Conn.delete_session(session_key)
    |> Plug.assign_current_user(nil, config)
  end

  defp get_session(conn, config) do
    key = Conn.get_session(conn, session_key(config))

    store(config).get(config, key)
  end

  defp session_key(config) do
    Config.get(config, :session_key, "auth")
  end

  defp store(config) do
    Config.get(config, :session_store, CredentialsCache)
  end
end
