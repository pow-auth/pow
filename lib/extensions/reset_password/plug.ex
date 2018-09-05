defmodule PowResetPassword.Plug do
  @moduledoc false
  alias Plug.Conn
  alias Pow.{Config, Store.Backend.EtsCache, UUID}
  alias PowResetPassword.{Ecto.Context, Store.ResetTokenCache}

  @spec change_user(Conn.t(), map()) :: map()
  def change_user(conn, params \\ %{}) do
    user =
      conn
      |> reset_password_user()
      |> case do
        nil ->
          conn
          |> Pow.Plug.fetch_config()
          |> Context.user_schema_mod()
          |> struct()

        user ->
          user
      end

    user.__struct__.pow_password_changeset(user, params)
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

  @spec create_reset_token(Conn.t(), map()) :: {:ok, map(), Conn.t()} | {:error, map(), Conn.t()}
  def create_reset_token(conn, params) do
    config = Pow.Plug.fetch_config(conn)
    user   =
      params
      |> Map.get("email")
      |> Context.get_by_email(config)

    maybe_create_reset_token(conn, user, config)
  end

  defp maybe_create_reset_token(conn, nil, _config) do
    changeset = change_user(conn)
    {:error, %{changeset | action: :update}, conn}
  end
  defp maybe_create_reset_token(conn, user, config) do
    token = UUID.generate()
    {store, store_config} = store(config)
    conn = put_reset_password_token(conn, token)

    store.put(store_config, token, user)

    {:ok, %{token: token, user: user}, conn}
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

  @spec update_user_password(Conn.t(), map()) :: {:ok, map(), Conn.t()} | {:error, map(), Conn.t()}
  def update_user_password(conn, params) do
    config = Pow.Plug.fetch_config(conn)
    token  = conn.params["id"]

    conn
    |> reset_password_user()
    |> Context.update_password(params, config)
    |> maybe_expire_token(conn, token, config)
  end

  defp maybe_expire_token({:ok, user}, conn, token, config) do
    expire_token(token, config)

    {:ok, user, conn}
  end
  defp maybe_expire_token({:error, changeset}, conn, _token, _config) do
    {:error, changeset, conn}
  end

  defp expire_token(token, config) do
    {store, store_config} = store(config)
    store.delete(store_config, token)
  end

  defp store(config) do
    backend = Config.get(config, :cache_store_backend, EtsCache)

    {ResetTokenCache, [backend: backend]}
  end
end
