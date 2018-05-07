defmodule Authex.Authorization.PlugTest do
  use ExUnit.Case
  doctest Authex

  alias Plug.Conn
  alias Authex.Authorization.{Plug, Plug.ConfigError}

  @default_config [current_user_assigns_key: :current_user]
  @admin_config [current_user_assigns_key: :current_admin_user]

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
end
