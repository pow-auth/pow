defmodule Authex.Authorization.Plug do
  @moduledoc """
  Authorization methods for Plug.
  """
  alias Plug.Conn
  alias Authex.{Authentication, Config}

  defmodule ConfigError do
    defexception [:message]
  end

  @private_config_key :authex_config

  @spec current_user(Conn.t()) :: map() | nil | no_return
  def current_user(conn) do
    current_user(conn, fetch_config(conn))
  end

  @spec current_user(Conn.t(), Keyword.t()) :: map() | nil
  def current_user(%{assigns: assigns}, config) do
    key = Config.current_user_assigns_key(config)

    Map.get(assigns, key, nil)
  end

  @spec assign_current_user(Conn.t(), any(), Keyword.t()) :: Conn.t()
  def assign_current_user(conn, user, config) do
    key = Config.current_user_assigns_key(config)

    Conn.assign(conn, key, user)
  end

  @spec put_config(Conn.t(), Keyword.t()) :: Conn.t()
  def put_config(conn, config) do
    Conn.put_private(conn, @private_config_key, config)
  end

  @spec fetch_config(Conn.t()) :: Keyword.t() | no_return
  def fetch_config(%{private: private}) do
    private[@private_config_key] || raise_no_config()
  end

  @spec authenticate_user(Conn.t(), map()) :: {:ok, map()} | {:error, term()}
  def authenticate_user(conn, params) do
    conn
    |> fetch_config()
    |> Config.get(:user_mod, nil)
    |> Kernel.||(raise_no_user_mod())
    |> Authentication.authenticate(params)
  end

  defp raise_no_config() do
    raise __MODULE__.ConfigError, message: "Authex configuration not found. Please set the Authex.Authorization.Plug.Session plug beforehand."
  end

  defp raise_no_user_mod() do
    raise __MODULE__.ConfigError, message: "Can't find user module. Please add the correct user module by setting the :user_mod config value."
  end
end
