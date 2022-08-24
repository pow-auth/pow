defmodule PowResetPassword.Plug do
  @moduledoc """
  Plug helper functions.
  """
  alias Plug.Conn
  alias Pow.{Config, Plug, Store.Backend.EtsCache, UUID}
  alias PowResetPassword.Ecto.Context, as: ResetPasswordContext
  alias PowResetPassword.Store.ResetTokenCache

  @doc """
  Creates a changeset from the user fetched in the connection.
  """
  @spec change_user(Conn.t(), map()) :: map()
  def change_user(conn, params \\ %{}) do
    user = reset_password_user(conn) || user_struct(conn)

    user.__struct__.reset_password_changeset(user, params)
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
  Verifies the signed token and fetches user from store.

  If a user is found, it'll be assigned to `conn.assigns` for key
  `:reset_password_user`.

  A `:pow_reset_password_decoded_token` key will be assigned in `conn.private`
  with the decoded token. This is used to invalidate the token when calling
  `update_user_password/2`.

  The token will be decoded and verified with `Pow.Plug.verify_token/4`.

  See `create_reset_token/2` for more on `:reset_password_token_store` config
  option.
  """
  @spec load_user_by_token(Conn.t(), binary()) :: {:ok, Conn.t()} | {:error, Conn.t()}
  def load_user_by_token(conn, signed_token) do
    config = Plug.fetch_config(conn)

    with {:ok, token}               <- Plug.verify_token(conn, signing_salt(), signed_token, config),
         user when not is_nil(user) <- fetch_user_from_token(token, config) do

      conn =
        conn
        |> Conn.put_private(:pow_reset_password_decoded_token, token)
        |> Conn.assign(:reset_password_user, user)

      {:ok, conn}
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

  The user should exist in `conn.assigns` for key `:reset_password_user` and
  the decoded token in `conn.private` for key
  `:pow_reset_password_decoded_token`. `load_user_by_token/2` will ensure this.

  See `create_reset_token/2` for more on `:reset_password_token_store` config
  option.
  """
  @spec update_user_password(Conn.t(), map()) :: {:ok, map(), Conn.t()} | {:error, map(), Conn.t()}
  def update_user_password(conn, params) do
    config = Plug.fetch_config(conn)

    conn
    |> reset_password_user()
    |> ResetPasswordContext.update_password(params, config)
    |> case do
      {:ok, user} ->
        expire_token(conn, config)

        {:ok, user, conn}

      {:error, changeset} ->
        {:error, changeset, conn}
    end
  end

  defp expire_token(%{private: %{pow_reset_password_decoded_token: token}}, config) do
    {store, store_config} = store(config)
    store.delete(store_config, token)
  end
  defp expire_token(_conn, _config) do
    IO.warn("no `:pow_reset_password_decoded_token` key found in `conn.private`, please call `#{inspect __MODULE__}.load_user_by_token/2` first")

    :ok
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
    store_config
    |> Keyword.put_new(:backend, Config.get(config, :cache_store_backend, EtsCache))
    |> Keyword.put_new(:pow_config, config)
  end
end
