defmodule Pow.Plug.SessionTest do
  use ExUnit.Case
  doctest Pow.Plug.Session

  alias Plug.{Conn, ProcessStore, Test}
  alias Plug.Session, as: PlugSession
  alias Pow.{Plug, Plug.Session, Store.Backend.EtsCache, Store.CredentialsCache}
  alias Pow.Test.{Ecto.Users.User, EtsCacheMock}

  @default_opts [
    current_user_assigns_key: :current_user,
    session_key: "auth",
    cache_store_backend: EtsCacheMock
  ]
  @store_config [backend: EtsCacheMock]
  @user %User{id: 1}

  setup do
    EtsCacheMock.init()

    conn = conn_with_plug_session()

    {:ok, conn: conn}
  end

  test "call/2 sets plug in :pow_config", %{conn: conn} do
    conn = run_plug(conn)
    expected_config = [mod: Session, plug: Session] ++ @default_opts

    assert is_nil(conn.assigns[:current_user])
    assert conn.private[:pow_config] == expected_config
  end

  test "call/2 with assigned current_user", %{conn: conn} do
    conn =
      conn
      |> Plug.assign_current_user("assigned", @default_opts)
      |> run_plug()

    assert conn.assigns[:current_user] == "assigned"
  end

  test "call/2 with stored current_user", %{conn: conn} do
    CredentialsCache.put(@store_config, "token", {@user, inserted_at: :os.system_time(:millisecond), fingerprint: "fingerprint"})

    conn =
      conn
      |> Conn.fetch_session()
      |> Conn.put_session(@default_opts[:session_key], "token")
      |> run_plug()

    assert conn.assigns[:current_user] == @user
    assert conn.private[:pow_session_metadata][:fingerprint] == "fingerprint"
  end

  test "call/2 with stored session and custom metadata", %{conn: conn} do
    inserted_at = :os.system_time(:millisecond)
    CredentialsCache.put(@store_config, "token", {@user, inserted_at: inserted_at, a: 1})

    conn =
      conn
      |> Conn.put_private(:pow_session_metadata, b: 2)
      |> Conn.fetch_session()
      |> Conn.put_session(@default_opts[:session_key], "token")
      |> run_plug()

    assert conn.assigns[:current_user] == @user
    assert conn.private[:pow_session_metadata][:inserted_at] == inserted_at
    assert conn.private[:pow_session_metadata][:a] == 1
  end

  test "call/2 with non existing cached key", %{conn: conn} do
    CredentialsCache.put(@store_config, "token", {@user, inserted_at: :os.system_time(:millisecond)})

    conn =
      conn
      |> Conn.fetch_session()
      |> Conn.put_session(@default_opts[:session_key], "invalid")
      |> run_plug()

    assert is_nil(conn.assigns[:current_user])
  end

  test "call/2 creates new session when :session_renewal_ttl reached", %{conn: conn} do
    ttl             = 100
    config          = Keyword.put(@default_opts, :session_ttl_renewal, ttl)
    timestamp       = :os.system_time(:millisecond)
    stale_timestamp = timestamp - ttl - 1
    init_conn       =
      conn
      |> Conn.fetch_session()
      |> Conn.put_session(config[:session_key], "token")

    CredentialsCache.put(@store_config, "token", {@user, inserted_at: timestamp, fingerprint: "fingerprint"})

    conn = run_plug(init_conn, config)

    assert session_id = get_session_id(conn)
    assert conn.assigns[:current_user] == @user

    CredentialsCache.put(@store_config, "token", {@user, inserted_at: stale_timestamp, fingerprint: "fingerprint"})
    CredentialsCache.put(@store_config, "newer_token", {@user, inserted_at: timestamp, fingerprint: "new_fingerprint"})

    conn = run_plug(init_conn, config)

    assert conn.assigns[:current_user] == @user
    assert new_session_id = get_session_id(conn)
    assert new_session_id != session_id
    assert {_user, metadata} = CredentialsCache.get(@store_config, new_session_id)
    assert metadata[:inserted_at] != stale_timestamp
    assert metadata[:fingerprint] == "fingerprint"
    assert conn.private[:pow_session_metadata][:fingerprint] == "fingerprint"
  end

  test "call/2 creates new session when :session_renewal_ttl reached and doesn't delete with simultanous request", %{conn: conn} do
    ttl             = 100
    session_id      = "token"
    config          = Keyword.put(@default_opts, :session_ttl_renewal, ttl)
    stale_timestamp = :os.system_time(:millisecond) - ttl - 1

    conn =
      conn
      |> Conn.fetch_session()
      |> Conn.put_session(config[:session_key], session_id)
      |> Conn.send_resp(200, "")
      |> recycle_session_conn()

    sid          = Conn.fetch_cookies(conn).cookies["foobar"]
    session_data = Process.get({:session, sid})

    CredentialsCache.put(@store_config, session_id, {@user, inserted_at: stale_timestamp})

    task_1 = Task.async(fn ->
      Process.put({:session, sid}, session_data)
      run_plug(conn, config)
    end)
    task_2 = Task.async(fn ->
      Process.put({:session, sid}, session_data)
      run_plug(conn, config)
    end)
    conn_1 = Task.await(task_1)
    conn_2 = Task.await(task_2)

    assert Plug.current_user(conn_1) == @user
    assert conn_1.resp_cookies["foobar"]
    refute get_session_id(conn_1) == session_id
    assert {@user, _metadata} = CredentialsCache.get(@store_config, get_session_id(conn_1))

    refute Plug.current_user(conn_2)
    refute conn_2.resp_cookies["foobar"]
    assert get_session_id(conn_2) == session_id
    assert CredentialsCache.get(@store_config, get_session_id(conn_2)) == :not_found
  end

  test "call/2 with prepended `:otp_app` session key", %{conn: conn} do
    CredentialsCache.put(@store_config, "token", {@user, inserted_at: :os.system_time(:millisecond)})

    config =
      @default_opts
      |> Keyword.delete(:session_key)
      |> Keyword.put(:otp_app, :test_app)
    conn =
      conn
      |> Conn.fetch_session()
      |> Conn.put_session("test_app_auth", "token")
      |> run_plug(config)

    assert conn.assigns[:current_user] == @user
  end

  # TODO: Remove by 1.1.0
  test "backwards compatible", %{conn: conn} do
    ttl             = 100
    config          = Keyword.put(@default_opts, :session_ttl_renewal, ttl)
    stale_timestamp = :os.system_time(:millisecond) - ttl - 1

    @store_config
    |> Keyword.put(:namespace, "credentials")
    |> EtsCacheMock.put({"token", {@user, stale_timestamp}})

    conn =
      conn
      |> Conn.fetch_session()
      |> Conn.put_session(config[:session_key], "token")
      |> run_plug(config)

    assert new_session_id = get_session_id(conn)
    assert new_session_id != "token"

    assert conn.assigns[:current_user] == @user
  end

  describe "create/2" do
    test "deletes existing and creates new session id", %{conn: new_conn} do
      conn =
        new_conn
        |> init_plug()
        |> run_do_create(@user)

      assert session_id = get_session_id(conn)
      assert {@user, metadata} = CredentialsCache.get(@store_config, session_id)
      assert is_binary(session_id)
      assert Plug.current_user(conn) == @user
      assert metadata[:inserted_at]
      assert metadata[:fingerprint]

      conn =
        conn
        |> recycle_session_conn()
        |> init_plug()
        |> run_do_create(@user)

      assert new_session_id = get_session_id(conn)
      assert {@user, new_metadata} = CredentialsCache.get(@store_config, new_session_id)
      assert is_binary(session_id)
      assert new_session_id != session_id
      assert CredentialsCache.get(@store_config, session_id) == :not_found
      assert Plug.current_user(conn) == @user
      assert metadata[:fingerprint] == new_metadata[:fingerprint]
    end

    test "renews plug session", %{conn: new_conn} do
      conn =
        new_conn
        |> init_plug()
        |> run_do_create(@user)

      assert %{"foobar" => %{value: plug_session_id}} = conn.resp_cookies

      conn =
        conn
        |> recycle_session_conn()
        |> init_plug()
        |> run_do_create(@user)

      assert %{"foobar" => %{value: new_plug_session_id}} = conn.resp_cookies

      refute plug_session_id == new_plug_session_id
    end

    test "creates with custom metadata", %{conn: conn} do
      inserted_at = :os.system_time(:millisecond) - 10
      conn =
        conn
        |> Conn.put_private(:pow_session_metadata, inserted_at: inserted_at, a: 1)
        |> init_plug()
        |> run_do_create(@user)

      assert conn.assigns[:current_user] == @user
      assert conn.private[:pow_session_metadata][:inserted_at] != inserted_at
      assert conn.private[:pow_session_metadata][:fingerprint]
      assert conn.private[:pow_session_metadata][:a] == 1
    end

    test "creates new session id with `:otp_app` prepended", %{conn: conn} do
      config =
        @default_opts
        |> Keyword.delete(:session_key)
        |> Keyword.put(:otp_app, :test_app)
      conn =
        conn
        |> init_plug(config)
        |> run_do_create(@user)

      refute get_session_id(conn)

      session_id = conn.private[:plug_session]["test_app_auth"]
      assert String.starts_with?(session_id, "test_app_")
    end
  end

  test "delete/1 removes session id", %{conn: new_conn} do
    conn =
      new_conn
      |> init_plug()
      |> run_do_create(@user)

    assert session_id = get_session_id(conn)
    assert {@user, _metadata} = CredentialsCache.get(@store_config, session_id)
    assert is_binary(session_id)
    assert Plug.current_user(conn) == @user

    conn =
      conn
      |> recycle_session_conn()
      |> init_plug()
      |> run_do_delete()

    refute new_session_id = get_session_id(conn)
    assert is_nil(new_session_id)
    assert CredentialsCache.get(@store_config, session_id) == :not_found
    assert is_nil(Plug.current_user(conn))
  end

  describe "with EtsCache backend" do
    setup do
      start_supervised!({EtsCache, []})

      :ok
    end

    test "call/2", %{conn: conn} do
      sesion_key = "auth"
      config     = [session_key: sesion_key]
      token      = "credentials_cache_test"
      timestamp  = :os.system_time(:millisecond)
      CredentialsCache.put(config, token, {@user, inserted_at: timestamp})

      :timer.sleep(100)

      config = [session_key: "auth"]
      conn =
        conn
        |> Conn.fetch_session()
        |> Conn.put_session("auth", token)
        |> run_plug(config)

      assert conn.assigns[:current_user] == @user
    end
  end

  defp conn_with_plug_session(conn \\ nil) do
    conn
    |> Kernel.||(Test.conn(:get, "/"))
    |> PlugSession.call(PlugSession.init(store: ProcessStore, key: "foobar"))
  end

  defp recycle_session_conn(old_conn) do
    :get
    |> Test.conn("/")
    |> Test.recycle_cookies(old_conn)
    |> conn_with_plug_session()
  end

  defp init_plug(conn, config \\ @default_opts) do
    opts = Session.init(config)

    Session.call(conn, opts)
  end

  defp run_plug(conn, config \\ @default_opts) do
    conn
    |> init_plug(config)
    |> Conn.send_resp(200, "")
  end

  def get_session_id(conn) do
    conn.private[:plug_session][@default_opts[:session_key]]
  end

  defp run_do_create(conn, user) do
    config = Plug.fetch_config(conn)

    conn
    |> Session.do_create(user, config)
    |> Conn.send_resp(200, "")
  end

  defp run_do_delete(conn) do
    config = Plug.fetch_config(conn)

    conn
    |> Session.do_delete(config)
    |> Conn.send_resp(200, "")
  end
end
