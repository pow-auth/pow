defmodule Authex.Authorization.PlugTest do
  use ExUnit.Case
  doctest Authex

  alias Plug.Conn
  alias Authex.Authorization.{Plug, Plug.ConfigError, Plug.Session}
  alias Authex.Test.{ConnHelpers, CredentialsCacheMock, UserMock}

  @default_config [
    current_user_assigns_key: :current_user,
    user_mod: UserMock,
    session_store: CredentialsCacheMock
  ]
  @admin_config Keyword.put(@default_config, :current_user_assigns_key, :current_admin_user)

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
    CredentialsCacheMock.init()

    conn = conn() |> ConnHelpers.with_session() |> Session.call(@default_config)
    refute conn.private[:plug_session]["auth"]
    refute Plug.current_user(conn)

    assert {:ok, loaded_conn} = Plug.authenticate_user(conn, %{"email" => "test@example.com", "password" => "secret"})
    assert Plug.current_user(loaded_conn) == %{id: 1}
    assert loaded_conn.private[:plug_session]["auth"]

    assert Plug.authenticate_user(conn, %{}) == {:error, :not_found}
    assert Plug.authenticate_user(conn, %{"email" => "test@example.com"}) == {:error, :invalid_password}
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

  test "clear_authenticated_user/1" do
    CredentialsCacheMock.init()

    conn = conn() |> ConnHelpers.with_session() |> Session.call(@default_config)
    assert {:ok, conn} = Plug.authenticate_user(conn, %{"email" => "test@example.com", "password" => "secret"})
    assert Plug.current_user(conn) == %{id: 1}
    assert session_id = conn.private[:plug_session]["auth"]
    assert CredentialsCacheMock.get(nil, session_id) == %{id: 1}

    conn = Plug.clear_authenticated_user(conn)
    refute Plug.current_user(conn)
    refute conn.private[:plug_session]["auth"]
    assert CredentialsCacheMock.get(nil, session_id) == :not_found
  end

  defp conn(config \\ @default_config) do
    %Conn{private: %{authex_config: config}}
  end
end
