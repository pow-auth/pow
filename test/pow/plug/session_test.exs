defmodule Pow.Plug.SessionTest do
  use ExUnit.Case
  doctest Pow.Plug.Session

  alias Plug.{Conn, ProcessStore, Test}
  alias Plug.Session, as: PlugSession
  alias Pow.{Plug, Plug.Session, Store.Backend.EtsCache, Store.CredentialsCache}
  alias Pow.Test.{Ecto.Users.User, EtsCacheMock, MessageVerifier}

  @default_opts [
    current_user_assigns_key: :current_user,
    session_key: "auth",
    cache_store_backend: EtsCacheMock,
    message_verifier: MessageVerifier
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

  test "call/2 uses existing config with no plug options", %{conn: conn} do
    assert_raise Pow.Config.ConfigError, "Pow configuration not found in connection. Please use a Pow plug that puts the Pow configuration in the plug connection.", fn ->
      run_plug(conn, [])
    end

    conn =
      conn
      |> Plug.put_config([a: 1])
      |> run_plug([])

    expected_config = [mod: Session, plug: Session] ++ [a: 1]

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
    session_id = store_in_cache("token", {@user, inserted_at: :os.system_time(:millisecond), fingerprint: "fingerprint"})
    conn       =
      conn
      |> Conn.fetch_session()
      |> Conn.put_session(@default_opts[:session_key], session_id)
      |> run_plug()

    assert conn.assigns[:current_user] == @user
    assert conn.private[:pow_session_metadata][:fingerprint] == "fingerprint"
  end

  test "call/2 with stored session and custom metadata", %{conn: conn} do
    inserted_at = :os.system_time(:millisecond)
    session_id  = store_in_cache("token", {@user, inserted_at: inserted_at, a: 1})

    conn =
      conn
      |> Conn.put_private(:pow_session_metadata, b: 2)
      |> Conn.fetch_session()
      |> Conn.put_session(@default_opts[:session_key], session_id)
      |> run_plug()

    assert conn.assigns[:current_user] == @user
    assert conn.private[:pow_session_metadata][:inserted_at] == inserted_at
    assert conn.private[:pow_session_metadata][:a] == 1
  end

  test "call/2 with non existing cached key", %{conn: conn} do
    _session_id = store_in_cache("token", {@user, inserted_at: :os.system_time(:millisecond)})
    invalid_id  = sign_token("invalid")

    conn =
      conn
      |> Conn.fetch_session()
      |> Conn.put_session(@default_opts[:session_key], invalid_id)
      |> run_plug()

    assert is_nil(conn.assigns[:current_user])
  end

  test "call/2 with unsigned session id", %{conn: conn} do
    session_id = "token"
    store_in_cache(session_id, {@user, inserted_at: :os.system_time(:millisecond), fingerprint: "fingerprint"})
    conn       =
      conn
      |> Conn.fetch_session()
      |> Conn.put_session(@default_opts[:session_key], session_id)
      |> run_plug()

    assert is_nil(conn.assigns[:current_user])
    assert {@user, _metadata} = CredentialsCache.get(@store_config, session_id)
  end

  test "call/2 creates new session when :session_renewal_ttl reached", %{conn: conn} do
    ttl             = 100
    config          = Keyword.put(@default_opts, :session_ttl_renewal, ttl)
    timestamp       = :os.system_time(:millisecond)
    stale_timestamp = timestamp - ttl - 1
    session_id      = store_in_cache("token", {@user, inserted_at: timestamp, fingerprint: "fingerprint"})
    init_conn       =
      conn
      |> Conn.fetch_session()
      |> Conn.put_session(config[:session_key], session_id)

    conn = run_plug(init_conn, config)

    assert session_id = get_session_id(conn)
    assert conn.assigns[:current_user] == @user

    store_in_cache("token", {@user, inserted_at: stale_timestamp, fingerprint: "fingerprint"})
    store_in_cache("newer_token", {@user, inserted_at: timestamp, fingerprint: "new_fingerprint"})

    conn = run_plug(init_conn, config)

    assert conn.assigns[:current_user] == @user
    assert new_session_id = get_session_id(conn)
    assert new_session_id != session_id
    assert {_user, metadata} = get_from_cache(new_session_id)
    assert metadata[:inserted_at] != stale_timestamp
    assert metadata[:fingerprint] == "fingerprint"
    assert conn.private[:pow_session_metadata][:fingerprint] == "fingerprint"
  end

  defmodule CredentialsCacheWaitDelete do
    alias Pow.Store.CredentialsCache

    @timeout :timer.seconds(5)

    defdelegate put(config, session_id, record_or_records), to: CredentialsCache

    defdelegate get(config, session_id), to: CredentialsCache

    def delete(config, session_id)do
      send(self(), {__MODULE__, :wait})

      receive do
        {__MODULE__, :commit} -> :ok
      after
        @timeout -> raise "Timeout reached"
      end

      CredentialsCache.delete(config, session_id)
    end
  end

  test "call/2 creates new session when :session_renewal_ttl reached and doesn't delete with simultanous request", %{conn: conn} do
    :ets.delete(EtsCacheMock)
    :ets.new(EtsCacheMock, [:ordered_set, :public, :named_table])

    ttl             = 100
    config          = Keyword.merge(@default_opts, session_ttl_renewal: ttl, credentials_cache_store: {CredentialsCacheWaitDelete, [ttl: :timer.minutes(30), namespace: "credentials"]})
    stale_timestamp = :os.system_time(:millisecond) - ttl - 1
    session_id      = store_in_cache("token", {@user, inserted_at: stale_timestamp})

    conn =
      conn
      |> Conn.fetch_session()
      |> Conn.put_session(config[:session_key], session_id)
      |> Conn.send_resp(200, "")
      |> recycle_session_conn()

    sid          = Conn.fetch_cookies(conn).cookies["foobar"]
    session_data = Process.get({:session, sid})

    CredentialsCache.put(@store_config, session_id, {@user, inserted_at: stale_timestamp})

    task_1 =
      fn ->
        Process.put({:session, sid}, session_data)
        run_plug(conn, config)
      end
      |> Task.async()
      |> wait_till_ready()

    conn_2 =
      fn ->
        Process.put({:session, sid}, session_data)
        run_plug(conn, config)
      end
      |> Task.async()
      |> continue_work()
      |> Task.await()

    conn_1 =
      task_1
      |> continue_work()
      |> Task.await()

    assert Plug.current_user(conn_1) == @user
    assert conn_1.resp_cookies["foobar"]
    refute get_session_id(conn_1) == session_id
    assert {@user, _metadata} = get_from_cache(get_session_id(conn_1))

    assert Plug.current_user(conn_2) == @user
    refute conn_2.resp_cookies["foobar"]
    assert get_session_id(conn_2) == session_id
    assert get_from_cache(get_session_id(conn_2)) == :not_found
  end

  defp wait_till_ready(%{pid: tracking_pid} = task) do
    :erlang.trace(tracking_pid, true, [:receive])
    assert_receive {:trace, ^tracking_pid, :receive, {CredentialsCacheWaitDelete, :wait}}

    task
  end

  defp continue_work(%{pid: tracking_pid} = task) do
    send(tracking_pid, {CredentialsCacheWaitDelete, :commit})

    task
  end

  test "call/2 with prepended `:otp_app` session key", %{conn: conn} do
    id = store_in_cache("token", {@user, inserted_at: :os.system_time(:millisecond)})

    config =
      @default_opts
      |> Keyword.delete(:session_key)
      |> Keyword.put(:otp_app, :test_app)
    conn =
      conn
      |> Conn.fetch_session()
      |> Conn.put_session("test_app_auth", id)
      |> run_plug(config)

    assert conn.assigns[:current_user] == @user
  end

  defmodule ContextMock do
    def get_by([id: :missing]), do: nil
  end

  test "call/2 when user doesn't exist in database and CredentialsCache reloads", %{conn: conn} do
    session_id = store_in_cache("token", {%User{id: :missing}, inserted_at: :os.system_time(:millisecond)})

    config =
      @default_opts
      |> Keyword.put(:users_context, ContextMock)
      |> Keyword.put(:credentials_cache_store, {Pow.Store.CredentialsCache, reload: true})

    conn =
      conn
      |> Conn.fetch_session()
      |> Conn.put_session(config[:session_key], session_id)
      |> run_plug(config)

    refute conn.assigns[:current_user]
    assert get_from_cache(session_id) == :not_found
  end

  # TODO: Remove by 1.1.0
  test "backwards compatible", %{conn: conn} do
    ttl             = 100
    config          = Keyword.put(@default_opts, :session_ttl_renewal, ttl)
    stale_timestamp = :os.system_time(:millisecond) - ttl - 1
    session_id      = sign_token("token")

    @store_config
    |> Keyword.put(:namespace, "credentials")
    |> EtsCacheMock.put({"token", {@user, stale_timestamp}})

    conn =
      conn
      |> Conn.fetch_session()
      |> Conn.put_session(config[:session_key], session_id)
      |> run_plug(config)

    assert new_session_id = get_session_id(conn)
    assert new_session_id != session_id

    assert conn.assigns[:current_user] == @user
  end

  describe "create/2" do
    test "deletes existing and creates new session id", %{conn: new_conn} do
      conn =
        new_conn
        |> init_plug()
        |> run_do_create(@user)

      assert session_id = get_session_id(conn)
      assert {@user, metadata} = get_from_cache(session_id)
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
      assert {@user, new_metadata} = get_from_cache(new_session_id)
      assert is_binary(session_id)
      assert new_session_id != session_id
      assert get_from_cache(session_id) == :not_found
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
      assert {:ok, decoded_session_id} = Plug.verify_token(conn, Atom.to_string(Session), session_id)
      assert String.starts_with?(decoded_session_id, "test_app_")
    end
  end

  test "delete/2 removes session id", %{conn: new_conn} do
    conn =
      new_conn
      |> init_plug()
      |> run_do_create(@user)

    assert session_id = get_session_id(conn)
    assert {@user, _metadata} = get_from_cache(session_id)
    assert is_binary(session_id)
    assert Plug.current_user(conn) == @user

    conn =
      conn
      |> recycle_session_conn()
      |> init_plug()
      |> run_do_delete()

    refute new_session_id = get_session_id(conn)
    assert is_nil(new_session_id)
    assert get_from_cache(session_id) == :not_found
    assert is_nil(Plug.current_user(conn))
  end

  test "delete/2 deletes when call create in sequence", %{conn: conn} do
    conn =
      conn
      |> init_plug(@default_opts)
      |> Session.do_create(@user, @default_opts)
      |> run_do_delete()

    refute get_session_id(conn)
    assert is_nil(Plug.current_user(conn))
  end

  describe "with EtsCache backend" do
    setup do
      start_supervised!({EtsCache, []})

      :ok
    end

    test "call/2", %{conn: conn} do
      timestamp  = :os.system_time(:millisecond)
      session_id = store_in_cache("credentials_cache_test", {@user, inserted_at: timestamp}, [])

      conn =
        conn
        |> Conn.fetch_session()
        |> Conn.put_session("auth", session_id)
        |> run_plug(session_key: "auth", message_verifier: MessageVerifier)

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

  defp store_in_cache(token, value, store_config \\ @store_config) do
    CredentialsCache.put(store_config, token, value)

    sign_token(token)
  end

  defp sign_token(token) do
    Plug.sign_token(%Conn{}, Atom.to_string(Session), token, @default_opts)
  end

  defp get_from_cache(token) do
    assert {:ok, token} = Plug.verify_token(%Conn{}, Atom.to_string(Session), token, @default_opts)

    CredentialsCache.get(@store_config, token)
  end
end
