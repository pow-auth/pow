defmodule Authex.Authorization.PlugTest do
  use ExUnit.Case
  doctest Authex

  alias Plug.Conn
  alias Authex.Authorization.{Plug, Plug.ConfigError}

  @default_config [current_user_assigns_key: :current_user, user_mod: __MODULE__.User]
  @admin_config [current_user_assigns_key: :current_admin_user, user_mod: __MODULE__.User]

  defmodule User do
    def authenticate(%{"email" => "test@example.com", "password" => "secret"}), do: {:ok, %{id: 1}}
    def authenticate(%{"email" => "test@example.com"}), do: {:error, :invalid_password}
    def authenticate(_params), do: {:error, :not_found}
  end

  test "current_user/1" do
    assert_raise ConfigError, "Authex configuration not found. Please set the Authex.Authorization.Plug.Session plug beforehand.", fn ->
      Plug.current_user(%Conn{private: %{}, assigns: %{}})
    end

    user = %{id: 1}
    conn = %Conn{assigns: %{current_user: user}, private: %{authex_config: @default_config}}
    assert Plug.current_user(conn) == user

    conn = %Conn{assigns: %{current_user: user}, private: %{authex_config: @admin_config}}
    assert is_nil(Plug.current_user(conn))
  end

  test "current_user/2" do
    assert is_nil(Plug.current_user(%Conn{assigns: %{}}, @default_config))

    user = %{id: 1}
    conn = %Conn{assigns: %{current_user: user}}

    assert Plug.current_user(conn, @default_config) == user
    assert is_nil(Plug.current_user(conn, @admin_config))
  end

  test "assign_current_user/2" do
    user = %{id: 1}
    conn = %Conn{assigns: %{}}
    assert Plug.assign_current_user(conn, %{id: 1}, @default_config) == %Conn{assigns: %{current_user: user}}

    assert Plug.assign_current_user(conn, %{id: 1}, @admin_config) == %Conn{assigns: %{current_admin_user: user}}
  end

  test "authenticate_user/2" do
    assert Plug.authenticate_user(conn(), %{"email" => "test@example.com", "password" => "secret"}) == {:ok, %{id: 1}}
    assert Plug.authenticate_user(conn(), %{}) == {:error, :not_found}
    assert Plug.authenticate_user(conn(), %{"email" => "test@example.com"}) == {:error, :invalid_password}
  end

  test "authenticate_user/2 with missing user_mod" do
    assert_raise ConfigError, "Can't find user module. Please add the correct user module by setting the :user_mod config value.", fn ->
      Plug.authenticate_user(conn([]), %{})
    end
  end

  test "authenticate_user/2 with invalid user_mod" do
    assert_raise UndefinedFunctionError, fn ->
      Plug.authenticate_user(conn(user_mod: Invalid), %{})
    end
  end

  defp conn(config \\ @default_config) do
    %Conn{private: %{authex_config: config}}
  end
end
