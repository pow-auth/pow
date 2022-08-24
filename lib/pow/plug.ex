defmodule Pow.Plug do
  @moduledoc """
  Plug helper functions.
  """
  alias Plug.Conn
  alias Pow.{Config, Operations, Plug.MessageVerifier}

  @private_config_key :pow_config

  @doc """
  Get the current user assigned to the conn.

  The config is fetched from the conn. See `current_user/2` for more.
  """
  @spec current_user(Conn.t()) :: map() | nil
  def current_user(conn) do
    current_user(conn, fetch_config(conn))
  end

  @doc """
  Get the current user assigned to the conn.

  This will fetch the user from the assigns map in the conn. The key is by
  default `:current_user`, but it can be overridden with
  `:current_user_assigns_key` configuration option.
  """
  @spec current_user(Conn.t(), Config.t()) :: map() | nil
  def current_user(%{assigns: assigns}, config) do
    key = current_user_assigns_key(config)

    Map.get(assigns, key)
  end

  @doc """
  Assign an authenticated user to the connection.

  This will assign the user to the conn. The key is by default `:current_user`,
  but it can be overridden with `:current_user_assigns_key` configuration
  option.
  """
  @spec assign_current_user(Conn.t(), any(), Config.t()) :: Conn.t()
  def assign_current_user(conn, user, config) do
    key = current_user_assigns_key(config)

    Conn.assign(conn, key, user)
  end

  defp current_user_assigns_key(config) do
    Config.get(config, :current_user_assigns_key, :current_user)
  end

  @doc """
  Put the provided config as a private key in the connection.
  """
  @spec put_config(Conn.t(), Config.t()) :: Conn.t()
  def put_config(conn, config) do
    Conn.put_private(conn, @private_config_key, config)
  end

  @doc """
  Fetch configuration from the private key in the connection.

  It'll raise an error if configuration hasn't been set as a private key.
  """
  @spec fetch_config(Conn.t()) :: Config.t()
  def fetch_config(%{private: private}) do
    private[@private_config_key] || no_config_error!()
  end

  @doc """
  Prepend namespace found in Plug Pow configuration to binary.

  Will prepend `:otp_app` if exists in configuration.
  """
  @spec prepend_with_namespace(Config.t(), binary()) :: binary()
  def prepend_with_namespace(config, string) do
    case fetch_namespace(config) do
      nil       -> string
      namespace -> "#{namespace}_#{string}"
    end
  end

  defp fetch_namespace(config), do: Config.get(config, :otp_app)

  @doc """
  Authenticates a user.

  If successful, a new session will be created.
  """
  @spec authenticate_user(Conn.t(), map()) :: {:ok | :error, Conn.t()}
  def authenticate_user(conn, params) do
    config = fetch_config(conn)

    params
    |> Operations.authenticate(config)
    |> case do
      nil  -> {:error, conn}
      user -> {:ok, create(conn, user, config)}
    end
  end

  # TODO: Remove by 1.1.0
  @doc false
  @deprecated "Use `delete/1` instead"
  @spec clear_authenticated_user(Conn.t()) :: {:ok, Conn.t()}
  def clear_authenticated_user(conn), do: {:ok, delete(conn)}

  @doc """
  Creates a changeset from the current authenticated user.
  """
  @spec change_user(Conn.t(), map()) :: map()
  def change_user(conn, params \\ %{}) do
    config = fetch_config(conn)

    case current_user(conn, config) do
      nil  -> Operations.changeset(params, config)
      user -> Operations.changeset(user, params, config)
    end
  end

  @doc """
  Creates a new user.

  If successful, a new session will be created.
  """
  @spec create_user(Conn.t(), map()) :: {:ok, map(), Conn.t()} | {:error, map(), Conn.t()}
  def create_user(conn, params) do
    config = fetch_config(conn)

    params
    |> Operations.create(config)
    |> maybe_create_auth(conn, config)
  end

  @doc """
  Updates the current authenticated user.

  If successful, a new session will be created.
  """
  @spec update_user(Conn.t(), map()) :: {:ok, map(), Conn.t()} | {:error, map(), Conn.t()}
  def update_user(conn, params) do
    config = fetch_config(conn)

    conn
    |> current_user(config)
    |> Operations.update(params, config)
    |> maybe_create_auth(conn, config)
  end

  @doc """
  Deletes the current authenticated user.

  If successful, the user authentication will be cleared from the session.
  """
  @spec delete_user(Conn.t()) :: {:ok, map(), Conn.t()} | {:error, map(), Conn.t()}
  def delete_user(conn) do
    config = fetch_config(conn)

    conn
    |> current_user(config)
    |> Operations.delete(config)
    |> case do
      {:ok, user}         -> {:ok, user, delete(conn, config)}
      {:error, changeset} -> {:error, changeset, conn}
    end
  end

  defp maybe_create_auth({:ok, user}, conn, config) do
    {:ok, user, create(conn, user, config)}
  end
  defp maybe_create_auth({:error, changeset}, conn, _config) do
    {:error, changeset, conn}
  end

  # TODO: Remove by 1.1.0
  @doc false
  @deprecated "Use `get_plug/1` instead"
  @spec get_mod(Config.t()) :: atom()
  def get_mod(config), do: get_plug(config)

  @spec get_plug(Config.t()) :: atom()
  def get_plug(config) do
    config[:plug] || no_plug_error!()
  end

  @doc """
  Call `create/3` for the Pow plug set for the `conn`.
  """
  @spec create(Conn.t(), map()) :: Conn.t()
  def create(conn, user), do: create(conn, user, fetch_config(conn))

  @spec create(Conn.t(), map(), Config.t()) :: Conn.t()
  def create(conn, user, config), do: get_plug(config).do_create(conn, user, config)

  @doc """
  Call `delete/2` for the Pow plug set for the `conn`.
  """
  @spec delete(Conn.t()) :: Conn.t()
  def delete(conn), do: delete(conn, fetch_config(conn))

  @spec delete(Conn.t(), Config.t()) :: Conn.t()
  def delete(conn, config), do: get_plug(config).do_delete(conn, config)

  @spec no_config_error!() :: no_return()
  defp no_config_error!,
    do: Config.raise_error("Pow configuration not found in connection. Please use a Pow plug that puts the Pow configuration in the plug connection.")

  @spec no_plug_error!() :: no_return()
  defp no_plug_error!,
    do: Config.raise_error("Pow plug was not found in config. Please use a Pow plug that puts the `:plug` in the Pow configuration.")

  @doc false
  @spec __prevent_user_enumeration__(Conn.t(), any()) :: boolean()
  def __prevent_user_enumeration__(%{private: %{pow_prevent_user_enumeration: false}}, _changeset), do: false
  def __prevent_user_enumeration__(_conn, %{errors: errors}), do: unique_constraint_error?(errors, :email)
  def __prevent_user_enumeration__(_conn, _any), do: true

  defp unique_constraint_error?(errors, field) do
    Enum.find_value(errors, false, fn
      {^field, {_msg, [constraint: :unique, constraint_name: _name]}} -> true
      _any                                                            -> false
    end)
  end

  @doc """
  Signs a token for public consumption.

  Used to prevent timing attacks with token lookup.

  This uses `Pow.Plug.MessageVerifier` by default, but can be changed if the
  Pow configuration is set with `:message_verifier`. `Pow.Plug.MessageVerifier`
  can also be configured in this way if `:message_verifier` is set to
  `{Pow.Plug.MessageVerifier, key_generator_opts: [length: 64]}`
  """

  @spec sign_token(Conn.t(), binary(), binary(), Config.t() | nil) :: binary()
  def sign_token(conn, salt, token, config \\ nil) do
    config           = config || fetch_config(conn)
    {module, config} = message_verifier_module(config)

    module.sign(conn, salt, token, config)
  end

  @doc """
  Decodes and verifies a token.

  Used to prevent timing attacks with token lookup.

  This uses `Pow.Plug.MessageVerifier` by default, but can be changed if the
  Pow configuration is set with `:message_verifier`. `Pow.Plug.MessageVerifier`
  can also be configured in this way if `:message_verifier` is set to
  `{Pow.Plug.MessageVerifier, key_generator_opts: [length: 64]}`
  """
  @spec verify_token(Conn.t(), binary(), binary(), Config.t() | nil) :: {:ok, binary()} | :error
  def verify_token(conn, salt, token, config \\ nil) do
    config           = config || fetch_config(conn)
    {module, config} = message_verifier_module(config)

    module.verify(conn, salt, token, config)
  end

  defp message_verifier_module(config) do
    case Config.get(config, :message_verifier, MessageVerifier) do
      {module, config} -> {module, config}
      module           -> {module, []}
    end
  end
end
