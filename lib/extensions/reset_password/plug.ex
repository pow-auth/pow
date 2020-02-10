defmodule PowResetPassword.Plug do
  @moduledoc """
  Plug helper methods.
  """
  alias Plug.Conn
  alias Pow.{Config, Plug, Store.Backend.EtsCache, UUID}
  alias PowResetPassword.Ecto.Context, as: ResetPasswordContext
  alias PowResetPassword.{Ecto.Schema, Store.ResetTokenCache}

  @doc """
  Creates a changeset from the user fetched in the connection.
  """
  @spec change_user(Conn.t(), map()) :: map()
  def change_user(conn, params \\ %{}) do
    user = reset_password_user(conn) || user_struct(conn)

    Schema.reset_password_changeset(user, params)
  end

  defp user_struct(conn) do
    conn
    |> Plug.fetch_config()
    |> Config.user!()
    |> struct()
  end

  # TODO: Remove by 1.1.0
  @doc false
  @deprecated "No longer used"
  def assign_reset_password_user(conn, user) do
    Conn.assign(conn, :reset_password_user, user)
  end

  @doc """
  Finds a user for the provided params, creates a token, and stores the user
  for the token.

  The returned `:token` is signed for public consumption using
  `Pow.Plug.sign_token/4`. Additionally `Pow.UUID.generate/0` is called whether
  the user exists or not to prevent timing attacks.

  `:reset_password_token_store` can be passed in the config for the conn. This
  value defaults to
  `{PowResetPassword.Store.ResetTokenCache, backend: Pow.Store.Backend.EtsCache}`.
  The `Pow.Store.Backend.EtsCache` backend store can be changed with the
  `:cache_store_backend` option.
  """
  @spec create_reset_token(Conn.t(), map()) :: {:ok, map(), Conn.t()} | {:error, map(), Conn.t()}
  def create_reset_token(conn, params) do
    config = Plug.fetch_config(conn)
    token  = UUID.generate()

    params
    |> Map.get("email")
    |> ResetPasswordContext.get_by_email(config)
    |> case do
      nil ->
        {:error, change_user(conn, params), conn}

      user ->
        {store, store_config} = store(config)

        store.put(store_config, token, user)

        signed = Plug.sign_token(conn, signing_salt(), token, config)

        {:ok, %{token: signed, user: user}, conn}
    end
  end

  defp signing_salt(), do: Atom.to_string(__MODULE__)

  @doc """
  Verifies the signed token and fetches invited user from store.

  If a user is found, it'll be assigned to `conn.assign` for key
  `:reset_password_user`.

  The token will be decoded and verified with `Pow.Plug.verify_token/4`.

  See `create_reset_token/2` for more on `:reset_password_token_store` config
  option.
  """
  @spec load_user_by_token(Conn.t(), binary()) :: {:ok, Conn.t()} | {:error, Conn.t()}
  def load_user_by_token(conn, signed_token) do
    config = Plug.fetch_config(conn)

    with {:ok, token}               <- Plug.verify_token(conn, signing_salt(), signed_token, config),
         user when not is_nil(user) <- fetch_user_from_token(token, config) do
      {:ok, Conn.assign(conn, :reset_password_user, user)}
    else
      _any -> {:error, conn}
    end
  end

  defp fetch_user_from_token(token, config) do
    {store, store_config} = store(config)

    store_config
    |> store.get(token)
    |> case do
      :not_found -> nil
      user       -> user
    end
  end

  # TODO: Remove by 1.1.0
  @doc false
  @deprecated "Use `load_user_by_token/2` instead"
  def user_from_token(conn, token) do
    {store, store_config} =
      conn
      |> Plug.fetch_config()
      |> store()

    store_config
    |> store.get(token)
    |> case do
      :not_found -> nil
      user       -> user
    end
  end

  @doc """
  Updates the password for the user fetched in the connection.

  See `create_reset_token/2` for more on `:reset_password_token_store` config
  option.

  The token will be decoded and verified with `Pow.Plug.verify_token/4`.
  """
  @spec update_user_password(Conn.t(), map()) :: {:ok, map(), Conn.t()} | {:error, map(), Conn.t()}
  def update_user_password(conn, params) do
    config = Plug.fetch_config(conn)
    token  = conn.params["id"]

    conn
    |> reset_password_user()
    |> ResetPasswordContext.update_password(params, config)
    |> maybe_expire_token(conn, token, config)
  end

  defp maybe_expire_token({:ok, user}, conn, token, config) do
    case Plug.verify_token(conn, signing_salt(), token, config) do
      :error       -> :ok
      {:ok, token} -> expire_token(token, config)
    end

    {:ok, user, conn}
  end
  defp maybe_expire_token({:error, changeset}, conn, _token, _config) do
    {:error, changeset, conn}
  end

  defp expire_token(token, config) do
    {store, store_config} = store(config)
    store.delete(store_config, token)
  end

  defp reset_password_user(conn) do
    conn.assigns[:reset_password_user]
  end

  defp store(config) do
    case Config.get(config, :reset_password_token_store) do
      {store, store_config} -> {store, store_opts(config, store_config)}
      nil                   -> {ResetTokenCache, store_opts(config)}
    end
  end

  defp store_opts(config, store_config \\ []) do
    Keyword.put_new(store_config, :backend, Config.get(config, :cache_store_backend, EtsCache))
  end
end
