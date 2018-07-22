defmodule PowResetPassword.Plug do
  @moduledoc false
  alias Plug.Conn
  alias Pow.{Config, Ecto.Schema.Changeset, Store.Backend.EtsCache, UUID}
  alias PowResetPassword.{Ecto.Context, Store.ResetTokenCache}

  @spec change_user(Conn.t(), map()) :: map()
  def change_user(conn, params \\ %{}) do
    config   = Pow.Plug.fetch_config(conn)
    user =
      conn
      |> reset_password_user()
      |> case do
        nil  -> config |> Context.user_schema_mod() |> struct()
        user -> user
      end

    Changeset.password_changeset(user, params, config)
  end

  @spec assign_reset_password_user(Conn.t(), map()) :: Conn.t()
  def assign_reset_password_user(conn, user) do
    Conn.assign(conn, :reset_password_user, user)
  end

  defp reset_password_user(conn) do
    conn.assigns[:reset_password_user]
  end

  defp put_reset_password_token(conn, token) do
    Conn.put_private(conn, :reset_password_token, token)
  end

  @spec reset_password_token(Conn.t()) :: binary()
  def reset_password_token(conn) do
    conn.private[:reset_password_token]
  end

  @spec create_reset_token(Conn.t(), map() | nil) :: {:ok, Conn.t()} | {:error, map()} | no_return
  def create_reset_token(conn, nil) do
    changeset = change_user(conn)
    {:error, %{changeset | action: :update}}
  end
  def create_reset_token(conn, user) do
    token = UUID.generate()
    {store, store_config} =
      conn
      |> Pow.Plug.fetch_config()
      |> store()
    conn = put_reset_password_token(conn, token)

    store.put(store_config, token, user)

    {:ok, conn}
  end

  @spec load_user(Conn.t(), map()) :: Conn.t() | nil
  def load_user(conn, params) do
    email = Map.get(params, "email")

    conn
    |> Pow.Plug.fetch_config()
    |> Context.get_by_email(email)
  end

  @spec user_from_token(Conn.t(), binary()) :: map() | nil
  def user_from_token(conn, token) do
    {store, store_config} =
      conn
      |> Pow.Plug.fetch_config()
      |> store()

    store_config
    |> store.get(token)
    |> case do
      :not_found -> nil
      user       -> user
    end
  end

  @spec update_user_password(Conn.t(), map()) :: {:ok, Conn.t()} | {:error, Changeset.t()}
  def update_user_password(conn, params) do
    user   = reset_password_user(conn)
    config = Pow.Plug.fetch_config(conn)
    token  = conn.params["id"]

    config
    |> Context.update_password(user, params)
    |> case do
      {:ok, _user}        -> {:ok, expire_token(conn, token)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  def expire_token(conn, token) do
    {store, store_config} =
      conn
      |> Pow.Plug.fetch_config()
      |> store()

    store.delete(store_config, token)

    conn
  end

  defp store(config) do
    backend = Config.get(config, :cache_store_backend, EtsCache)

    {ResetTokenCache, [backend: backend]}
  end
end
