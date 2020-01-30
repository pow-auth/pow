defmodule Pow.PlugTest do
  use ExUnit.Case
  doctest Pow.Plug

  alias Plug.{Conn, Test}
  alias Pow.{Config, Config.ConfigError, Plug, Plug.Session}
  alias Pow.Test.{ConnHelpers, ContextMock, Ecto.Users.User, EtsCacheMock}

  @default_config [
    current_user_assigns_key: :current_user,
    users_context: ContextMock,
    cache_store_backend: EtsCacheMock,
    user: User
  ]
  @admin_config Config.put(@default_config, :current_user_assigns_key, :current_admin_user)

  test "current_user/1" do
    assert_raise ConfigError, "Pow configuration not found in connection. Please use a Pow plug that puts the Pow configuration in the plug connection.", fn ->
      Plug.current_user(%Conn{private: %{}, assigns: %{}})
    end

    user = %{id: 1}
    conn = %Conn{assigns: %{current_user: user}, private: %{pow_config: @default_config}}
    assert Plug.current_user(conn) == user

    conn = %Conn{assigns: %{current_user: user}, private: %{pow_config: @admin_config}}
    assert is_nil(Plug.current_user(conn))
  end

  test "current_user/2" do
    assert is_nil(Plug.current_user(%Conn{assigns: %{}}, @default_config))

    user = %{id: 1}
    conn = %Conn{assigns: %{current_user: user}}

    assert Plug.current_user(conn, @default_config) == user
    assert is_nil(Plug.current_user(conn, @admin_config))
  end

  test "assign_current_user/3" do
    user = %{id: 1}
    conn = %Conn{assigns: %{}}
    assert Plug.assign_current_user(conn, %{id: 1}, @default_config) == %Conn{assigns: %{current_user: user}}

    assert Plug.assign_current_user(conn, %{id: 1}, @admin_config) == %Conn{assigns: %{current_admin_user: user}}
  end

  test "authenticate_user/2" do
    EtsCacheMock.init()

    conn = init_session_conn()

    refute fetch_session_id(conn)
    refute Plug.current_user(conn)

    assert {:ok, loaded_conn} = Plug.authenticate_user(conn, %{"email" => "test@example.com", "password" => "secret"})
    assert user = Plug.current_user(loaded_conn)
    assert user.id == 1
    assert fetch_session_id(loaded_conn)

    assert {:error, conn} = Plug.authenticate_user(conn, %{})
    refute Plug.current_user(conn)

    assert {:error, conn} = Plug.authenticate_user(conn, %{"email" => "test@example.com"})
    refute Plug.current_user(conn)
  end

  test "authenticate_user/2 with missing user" do
    assert_raise ConfigError, "No `:user` configuration option found.", fn ->
      Plug.authenticate_user(conn([]), %{})
    end
  end

  test "authenticate_user/2 with invalid users_context" do
    assert_raise UndefinedFunctionError, fn ->
      Plug.authenticate_user(conn(users_context: Invalid), %{})
    end
  end

  test "authenticate_user/2 with missing plug config" do
    assert_raise ConfigError, "Pow plug was not found in config. Please use a Pow plug that puts the `:plug` in the Pow configuration.", fn ->
      Plug.authenticate_user(conn(), %{"email" => "test@example.com", "password" => "secret"})
    end
  end

  test "clear_authenticated_user/1" do
    EtsCacheMock.init()

    conn = auth_user_conn()
    assert user = Plug.current_user(conn)
    assert session_id = fetch_session_id(conn)
    assert {key, _metadata} = EtsCacheMock.get([namespace: "credentials"], session_id)
    assert EtsCacheMock.get([namespace: "credentials"], key) == user

    {:ok, conn} = Plug.clear_authenticated_user(conn)
    refute Plug.current_user(conn)
    refute fetch_session_id(conn)
    assert EtsCacheMock.get([namespace: "credentials"], session_id) == :not_found
  end

  test "change_user/2" do
    conn = conn()
    assert %Ecto.Changeset{} = Plug.change_user(conn)

    conn = Plug.assign_current_user(conn, %User{id: 1}, @default_config)
    changeset = Plug.change_user(conn)
    assert changeset.data.id == 1
  end

  test "create_user/2" do
    EtsCacheMock.init()

    conn = init_session_conn()

    assert {:error, _changeset, conn} = Plug.create_user(conn, %{})
    refute Plug.current_user(conn)
    refute fetch_session_id(conn)

    assert {:ok, user, conn} = Plug.create_user(conn, %{"email" => "test@example.com", "password" => "secret"})
    assert Plug.current_user(conn) == user
    assert fetch_session_id(conn)
  end

  test "update_user/2" do
    EtsCacheMock.init()

    conn = auth_user_conn()
    assert user = Plug.current_user(conn)
    assert session_id = fetch_session_id(conn)

    assert {:error, _changeset, conn} = Plug.update_user(conn, %{})
    assert Plug.current_user(conn) == user
    assert fetch_session_id(conn) == session_id

    assert {:ok, updated_user, conn} = Plug.update_user(conn, %{"email" => "test@example.com", "password" => "secret"})
    assert updated_user.id == :updated
    assert Plug.current_user(conn) == updated_user
    refute updated_user == user
    refute fetch_session_id(conn) == session_id
  end

  test "delete_user/2" do
    EtsCacheMock.init()

    conn = auth_user_conn()

    assert {:ok, user, conn} = Plug.delete_user(conn)
    assert user.id == :deleted
    refute Plug.current_user(conn)
    refute fetch_session_id(conn)
  end

  defp auth_user_conn() do
    conn        = init_session_conn()
    {:ok, conn} = Plug.authenticate_user(conn, %{"email" => "test@example.com", "password" => "secret"})
    conn        = Conn.send_resp(conn, 200, "")

    conn()
    |> Test.recycle_cookies(conn)
    |> init_session_conn()
  end

  defp init_session_conn(conn \\ nil) do
    (conn || conn(@default_config))
    |> ConnHelpers.init_session()
    |> Session.call(Session.init(@default_config))
  end

  defp fetch_session_id(conn) do
    conn = Conn.send_resp(conn, 200, "")

    Map.get(conn.private[:plug_session], "auth")
  end

  defp conn(config \\ @default_config) do
    :get
    |> ConnHelpers.conn("/")
    |> Conn.put_private(:pow_config, config)
  end
end
