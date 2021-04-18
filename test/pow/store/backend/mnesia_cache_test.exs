defmodule Pow.Store.Backend.MnesiaCacheTest do
  use ExUnit.Case
  doctest Pow.Store.Backend.MnesiaCache

  alias ExUnit.CaptureLog
  alias Pow.{Config, Config.ConfigError, Store.Backend.MnesiaCache}

  @default_config [namespace: "pow:test", ttl: :timer.hours(1)]

  setup_all do
    # Turn node into a distributed node with the given long name
    :net_kernel.start([:"master@127.0.0.1"])

    # Allow spawned nodes to fetch all code from this node
    :erl_boot_server.start([])
    {:ok, ipv4} = :inet.parse_ipv4_address('127.0.0.1')
    :erl_boot_server.add_slave(ipv4)

    :ok
  end

  describe "single node" do
    setup do
      :mnesia.kill()

      File.rm_rf!("tmp/mnesia")
      File.mkdir_p!("tmp/mnesia")

      start(@default_config)

      :ok
    end

    test "can put, get and delete records with persistent storage" do
      assert MnesiaCache.get(@default_config, "key") == :not_found

      MnesiaCache.put(@default_config, {"key", "value"})
      :timer.sleep(100)
      assert MnesiaCache.get(@default_config, "key") == "value"

      restart(@default_config)

      assert MnesiaCache.get(@default_config, "key") == "value"

      MnesiaCache.delete(@default_config, "key")
      :timer.sleep(100)
      assert MnesiaCache.get(@default_config, "key") == :not_found
    end

    test "can put multiple records" do
      assert MnesiaCache.get(@default_config, "key") == :not_found

      MnesiaCache.put(@default_config, [{"key1", "1"}, {"key2", "2"}])
      :timer.sleep(100)
      assert MnesiaCache.get(@default_config, "key1") == "1"
      assert MnesiaCache.get(@default_config, "key2") == "2"

      restart(@default_config)

      assert MnesiaCache.get(@default_config, "key1") == "1"
      assert MnesiaCache.get(@default_config, "key2") == "2"
    end

    test "with no `:ttl` config option" do
      assert_raise ConfigError, "`:ttl` configuration option is required for Pow.Store.Backend.MnesiaCache", fn ->
        MnesiaCache.put([namespace: "pow:test"], {"key", "value"})
      end
    end

    test "can match fetch all" do
      MnesiaCache.put(@default_config, {"key1", "value"})
      MnesiaCache.put(@default_config, {"key2", "value"})
      MnesiaCache.put(@default_config, {["namespace", "key"], "value"})
      :timer.sleep(100)

      assert MnesiaCache.all(@default_config, :_) ==  [{"key1", "value"}, {"key2", "value"}]
      assert MnesiaCache.all(@default_config, ["namespace", :_]) ==  [{["namespace", "key"], "value"}]
    end

    test "records auto purge with persistent storage" do
      config = Config.put(@default_config, :ttl, 100)

      MnesiaCache.put(config, {"key", "value"})
      MnesiaCache.put(config, [{"key1", "1"}, {"key2", "2"}])
      :timer.sleep(50)
      assert MnesiaCache.get(config, "key") == "value"
      assert MnesiaCache.get(config, "key1") == "1"
      assert MnesiaCache.get(config, "key2") == "2"
      :timer.sleep(100)
      assert MnesiaCache.get(config, "key") == :not_found
      assert MnesiaCache.get(config, "key1") == :not_found
      assert MnesiaCache.get(config, "key2") == :not_found

      # After restart
      MnesiaCache.put(config, {"key", "value"})
      MnesiaCache.put(config, [{"key1", "1"}, {"key2", "2"}])
      :timer.sleep(50)
      restart(config)
      assert MnesiaCache.get(config, "key") == "value"
      assert MnesiaCache.get(config, "key1") == "1"
      assert MnesiaCache.get(config, "key2") == "2"
      :timer.sleep(100)
      assert MnesiaCache.get(config, "key") == :not_found
      assert MnesiaCache.get(config, "key1") == :not_found
      assert MnesiaCache.get(config, "key2") == :not_found

      # After record expiration updated reschedules
      MnesiaCache.put(config, {"key", "value"})
      :timer.sleep(50)
      :mnesia.dirty_write({MnesiaCache, ["pow:test", "key"], {"value", :os.system_time(:millisecond) + 150}})
      :timer.sleep(100)
      assert MnesiaCache.get(config, "key") == "value"
      :timer.sleep(100)
      assert MnesiaCache.get(config, "key") == :not_found
    end

    test "when initiated with unexpected records" do
      :mnesia.dirty_write({MnesiaCache, ["pow:test", "key"], :invalid_value})

      assert CaptureLog.capture_log(fn ->
        restart(@default_config)
      end) =~ "[warn]  Found an unexpected record in the mnesia cache, please delete it: [\"pow:test\", \"key\"]"
    end

    # TODO: Remove by 1.1.0
    test "backwards compatible" do
      assert_capture_io_eval(quote do
        assert MnesiaCache.put(unquote(@default_config), "key", "value") == :ok
      end, "Pow.Store.Backend.MnesiaCache.put/3 is deprecated. Use `put/2` instead")

      :timer.sleep(50)

      assert_capture_io_eval(quote do
        assert MnesiaCache.keys(unquote(@default_config)) == [{"key", "value"}]
      end, "Pow.Store.Backend.MnesiaCache.keys/1 is deprecated. Use `all/2` instead")
    end
  end

  alias ExUnit.CaptureIO

  defp assert_capture_io_eval(quoted, message) do
    System.version()
    |> Version.match?(">= 1.8.0")
    |> case do
      true ->
        # Due to https://github.com/elixir-lang/elixir/pull/9626 it's necessary to
        # import `ExUnit.Assertions`
        pre_elixir_1_10_quoted =
          quote do
            import ExUnit.Assertions
          end

        assert CaptureIO.capture_io(:stderr, fn ->
          Code.eval_quoted([pre_elixir_1_10_quoted, quoted])
        end) =~ message

      false ->
        IO.warn("Please upgrade to Elixir 1.8 to captured and assert IO message: #{inspect message}")

        :ok
    end
  end

  defp start(config) do
    start_supervised!({MnesiaCache, config})
  end

  defp restart(config) do
    :ok = stop_supervised(MnesiaCache)
    :mnesia.stop()
    start(config)
  end

  describe "distributed nodes" do
    setup do
      File.rm_rf!("tmp/mnesia_multi")
      File.mkdir_p!("tmp/mnesia_multi")

      on_exit(fn ->
        :slave.stop(:'a@127.0.0.1')
        :slave.stop(:'b@127.0.0.1')
      end)

      :ok
    end

    @startup_wait_time 3_000
    @assertion_timeout 500

    test "will join cluster" do
      Process.register(self(), :test_process)

      # Init node a and write to it
      node_a = spawn_node("a")
      subscribe_log_events(node_a)
      {:ok, _pid} = :rpc.call(node_a, Supervisor, :start_child, [Pow.Supervisor, {MnesiaCache, @default_config}])
      expected_msg = "Mnesia cluster initiated on #{inspect node_a}"
      assert_receive {:log, ^node_a, :info, ^expected_msg}, @assertion_timeout
      assert :rpc.call(node_a, :mnesia, :table_info, [MnesiaCache, :storage_type]) == :disc_copies
      assert :rpc.call(node_a, :mnesia, :system_info, [:extra_db_nodes]) == []
      assert :rpc.call(node_a, :mnesia, :system_info, [:running_db_nodes]) == [node_a]
      assert :rpc.call(node_a, MnesiaCache, :put, [@default_config, {"key_set_on_a", "value"}])
      :timer.sleep(50)
      assert :rpc.call(node_a, MnesiaCache, :get, [@default_config, "key_set_on_a"]) == "value"

      # Join cluster with node b and ensures that it has node a data
      node_b = spawn_node("b")
      subscribe_log_events(node_b)
      config = @default_config ++ [extra_db_nodes: [node_a]]
      {:ok, _pid} = :rpc.call(node_b, Supervisor, :start_child, [Pow.Supervisor, {MnesiaCache, config}])
      expected_msg = "Joined mnesia cluster nodes [#{inspect node_a}] for #{inspect node_b}"
      assert_receive {:log, ^node_b, :info, ^expected_msg}, @assertion_timeout
      assert :rpc.call(node_b, :mnesia, :table_info, [MnesiaCache, :storage_type]) == :disc_copies
      assert :rpc.call(node_b, :mnesia, :system_info, [:extra_db_nodes]) == [node_a]
      assert :rpc.call(node_b, :mnesia, :system_info, [:running_db_nodes]) == [node_a, node_b]
      assert :rpc.call(node_b, MnesiaCache, :get, [@default_config, "key_set_on_a"]) == "value"

      # Write to node b can be fetched on node a
      assert :rpc.call(node_b, MnesiaCache, :put, [@default_config, {"key_set_on_b", "value"}])
      :timer.sleep(50)
      assert :rpc.call(node_a, MnesiaCache, :get, [@default_config, "key_set_on_b"]) == "value"

      # Set short TTL on node a
      config = Config.put(@default_config, :ttl, 150)
      assert :rpc.call(node_a, MnesiaCache, :put, [config, {"short_ttl_key_set_on_a", "value"}])
      :timer.sleep(50)

      # Stop node a
      :ok = :slave.stop(node_a)
      :timer.sleep(50)
      assert :rpc.call(node_b, :mnesia, :system_info, [:running_db_nodes]) == [node_b]

      # Ensure that node b invalidates with TTL set on node a
      assert :rpc.call(node_b, MnesiaCache, :get, [config, "short_ttl_key_set_on_a"]) == "value"
      :timer.sleep(50)
      assert :rpc.call(node_b, MnesiaCache, :get, [config, "short_ttl_key_set_on_a"]) == :not_found

      # Continue writing to node b with short TTL
      config = Config.put(@default_config, :ttl, @startup_wait_time + 100)
      assert :rpc.call(node_b, MnesiaCache, :put, [config, {"short_ttl_key_2_set_on_b", "value"}])
      :timer.sleep(50)
      assert :rpc.call(node_b, MnesiaCache, :get, [config, "short_ttl_key_2_set_on_b"]) == "value"

      # Start node a and join cluster
      startup_timestamp = System.monotonic_time(:millisecond)
      node_a = spawn_node("a")
      subscribe_log_events(node_a)
      config = @default_config ++ [extra_db_nodes: [node_b]]
      {:ok, _pid} = :rpc.call(node_a, Supervisor, :start_child, [Pow.Supervisor, {MnesiaCache, config}])
      expected_msg = "Joined mnesia cluster nodes [#{inspect node_b}] for #{inspect node_a}"
      assert_receive {:log, ^node_a, :info, ^expected_msg}, @assertion_timeout
      assert :rpc.call(node_b, :mnesia, :system_info, [:running_db_nodes]) == [node_a, node_b]
      assert :rpc.call(node_b, MnesiaCache, :get, [config, "short_ttl_key_2_set_on_b"]) == "value"
      assert :rpc.call(node_a, MnesiaCache, :get, [config, "short_ttl_key_2_set_on_b"]) == "value"

      # Stop node b
      :ok = :slave.stop(node_b)

      # Node a invalidates short TTL value written on node b
      startup_time = System.monotonic_time(:millisecond) - startup_timestamp
      :timer.sleep(@startup_wait_time - startup_time + 100)
      assert :rpc.call(node_a, MnesiaCache, :get, [config, "short_ttl_key_2_set_on_b"]) == :not_found
    end

    test "recovers from netsplit with MnesiaCache.Unsplit" do
      node_a = spawn_node("a")
      {:ok, _pid} = :rpc.call(node_a, Supervisor, :start_child, [Pow.Supervisor, {MnesiaCache, @default_config}])
      {:ok, _pid} = :rpc.call(node_a, Supervisor, :start_child, [Pow.Supervisor, MnesiaCache.Unsplit])

      # Create isolated table on node a
      {:atomic, :ok} = :rpc.call(node_a, :mnesia, :create_table, [:node_a_table, [disc_copies: [node_a]]])
      :ok = :rpc.call(node_a, :mnesia, :wait_for_tables, [[:node_a_table], 1_000])
      :ok = :rpc.call(node_a, :mnesia, :dirty_write, [{:node_a_table, :key, "a"}])

      node_b = spawn_node("b")
      config = @default_config ++ [extra_db_nodes: [node_a]]
      {:ok, _pid} = :rpc.call(node_b, Supervisor, :start_child, [Pow.Supervisor, {MnesiaCache, config}])
      {:ok, _pid} = :rpc.call(node_b, Supervisor, :start_child, [Pow.Supervisor, MnesiaCache.Unsplit])

      # Create isolated table on node b
      {:atomic, :ok} = :rpc.call(node_b, :mnesia, :create_table, [:node_b_table, [disc_copies: [node_b]]])
      :ok = :rpc.call(node_b, :mnesia, :wait_for_tables, [[:node_b_table], 1_000])
      :ok = :rpc.call(node_b, :mnesia, :dirty_write, [{:node_b_table, :key, "b"}])

      # Ensure that data writing on node a is replicated on node b
      assert :rpc.call(node_a, MnesiaCache, :put, [@default_config, {"key_1", "value"}])
      :timer.sleep(50)
      assert :rpc.call(node_a, MnesiaCache, :get, [@default_config, "key_1"]) == "value"
      assert :rpc.call(node_b, MnesiaCache, :get, [@default_config, "key_1"]) == "value"

      # Disconnect the nodes
      disconnect(node_b, node_a)

      # Continue writing on node a and node b
      assert :rpc.call(node_a, MnesiaCache, :put, [@default_config, {"key_1", "a"}])
      assert :rpc.call(node_a, MnesiaCache, :put, [@default_config, {"key_1_a", "value"}])
      assert :rpc.call(node_b, MnesiaCache, :put, [@default_config, {"key_1", "b"}])
      assert :rpc.call(node_b, MnesiaCache, :put, [@default_config, {"key_1_b", "value"}])
      :timer.sleep(50)
      assert :rpc.call(node_a, MnesiaCache, :get, [@default_config, "key_1"]) == "a"
      assert :rpc.call(node_a, MnesiaCache, :get, [@default_config, "key_1_a"]) == "value"
      assert :rpc.call(node_b, MnesiaCache, :get, [@default_config, "key_1"]) == "b"
      assert :rpc.call(node_b, MnesiaCache, :get, [@default_config, "key_1_b"]) == "value"

      # Subscribe to logger events
      Process.register(self(), :test_process)
      subscribe_log_events(node_a)
      subscribe_log_events(node_b)

      # Reconnect
      connect(node_b, node_a)

      # Node a used as master cluster and node b is purged
      assert_receive {:log, _node, :warn, "Detected a netsplit in the mnesia cluster with node " <> _reported_node}, @assertion_timeout
      assert_receive {:log, _node, :info, "The node :\"b@127.0.0.1\" has been healed and joined the mnesia cluster [:\"a@127.0.0.1\"]"}, @assertion_timeout
      assert :rpc.call(node_a, :mnesia, :system_info, [:running_db_nodes]) == [node_b, node_a]
      assert :rpc.call(node_a, MnesiaCache, :get, [@default_config, "key_1"]) == "a"
      assert :rpc.call(node_b, MnesiaCache, :get, [@default_config, "key_1"]) == "a"
      assert :rpc.call(node_a, MnesiaCache, :get, [@default_config, "key_1_b"]) == :not_found
      assert :rpc.call(node_b, MnesiaCache, :get, [@default_config, "key_1_a"]) == "value"

      # Isolated tables still works on both nodes
      assert :rpc.call(node_a, :mnesia, :dirty_read, [{:node_a_table, :key}]) == [{:node_a_table, :key, "a"}]
      assert :rpc.call(node_b, :mnesia, :dirty_read, [{:node_b_table, :key}]) == [{:node_b_table, :key, "b"}]

      flush_process_mailbox()

      # Shared tables unrelated to Pow can't reconnect
      {:atomic, :ok} = :rpc.call(node_a, :mnesia, :create_table, [:shared, [disc_copies: [node_a]]])
      {:atomic, :ok} = :rpc.call(node_b, :mnesia, :add_table_copy, [:shared, node_b, :disc_copies])
      disconnect(node_b, node_a)
      connect(node_b, node_a)
      assert_receive {:log, _node, :warn, "Detected a netsplit in the mnesia cluster with node " <> _reported_node}, @assertion_timeout
      assert_receive {:log, _node, :error, "Can't force reload unexpected tables [:shared] to heal " <> _reported_node}, @assertion_timeout
      assert :rpc.call(node_a, :mnesia, :system_info, [:running_db_nodes]) == [node_a]

      flush_process_mailbox()

      # Can't reconnect if table not defined in flush table
      reset_unsplit_trigger_inconsistent_database(node_b, node_a, flush_tables: [:unrelated])
      assert_receive {:log, _node, :warn, "Detected a netsplit in the mnesia cluster with node " <> _reported_node}, @assertion_timeout
      assert_receive {:log, _node, :error, "Can't force reload unexpected tables [:shared] to heal " <> _reported_node}, @assertion_timeout
      assert :rpc.call(node_b, :mnesia, :system_info, [:running_db_nodes]) == [node_b]

      flush_process_mailbox()

      # Can reconnect if `:flush_tables` is set to table
      reset_unsplit_trigger_inconsistent_database(node_b, node_a, flush_tables: [:shared])
      assert_receive {:log, _node, :warn, "Detected a netsplit in the mnesia cluster with node " <> _reported_node}, @assertion_timeout
      assert_receive {:log, _node, :info, "The node :\"b@127.0.0.1\" has been healed and joined the mnesia cluster [:\"a@127.0.0.1\"]"}, @assertion_timeout
      assert :rpc.call(node_a, :mnesia, :system_info, [:running_db_nodes]) == [node_b, node_a]

      flush_process_mailbox()

      # Resetting back to netsplit state
      disconnect(node_b, node_a)
      connect(node_b, node_a)
      assert_receive {:log, _node, :warn, "Detected a netsplit in the mnesia cluster with node " <> _reported_node}, @assertion_timeout
      assert_receive {:log, _node, :error, "Can't force reload unexpected tables [:shared] to heal " <> _reported_node}, @assertion_timeout
      assert :rpc.call(node_a, :mnesia, :system_info, [:running_db_nodes]) == [node_a]

      flush_process_mailbox()

      # Can reconnect if `:flush_tables` is set to `:all`
      reset_unsplit_trigger_inconsistent_database(node_b, node_a, flush_tables: :all)
      assert_receive {:log, _node, :warn, "Detected a netsplit in the mnesia cluster with node " <> _reported_node}, @assertion_timeout
      assert_receive {:log, _node, :info, "The node :\"b@127.0.0.1\" has been healed and joined the mnesia cluster [:\"a@127.0.0.1\"]"}, @assertion_timeout
      assert :rpc.call(node_a, :mnesia, :system_info, [:running_db_nodes]) == [node_b, node_a]
    end

    test "when init create cluster fails" do
      :mnesia.kill()
      Process.register(self(), :test_process)

      # Start Mnesia with configuration error
      node_a = spawn_node("a")
      config = @default_config ++ [table_opts: [disc_copies: [:invalid_node]]]
      subscribe_log_events(node_a)
      assert {:error, {{:create_table, {:aborted, {:not_active, Pow.Store.Backend.MnesiaCache, :invalid_node}}}, _}} = :rpc.call(node_a, Supervisor, :start_child, [Pow.Supervisor, {MnesiaCache, config}])
      assert_receive {:log, _node, :error, "Couldn't initialize mnesia cluster because: {:create_table, {:aborted, {:not_active, Pow.Store.Backend.MnesiaCache, :invalid_node}}}"}, @assertion_timeout
    end

    test "when init join cluster fails" do
      :mnesia.kill()
      Process.register(self(), :test_process)

      # Start Mnesia on node a uninitialized
      node_a = spawn_node("a")
      :ok = :rpc.call(node_a, :mnesia, :start, [])

      # Join cluster with node b
      node_b = spawn_node("b")
      config = @default_config ++ [extra_db_nodes: {Node, :list, []}]
      subscribe_log_events(node_b)
      assert {:error, {{:add_table_copy, {:aborted, {:no_exists, {Pow.Store.Backend.MnesiaCache, :cstruct}}}}, _}} = :rpc.call(node_b, Supervisor, :start_child, [Pow.Supervisor, {MnesiaCache, config}])
      assert_receive {:log, _node, :error, "Couldn't join mnesia cluster because: {:add_table_copy, {:aborted, {:no_exists, {Pow.Store.Backend.MnesiaCache, :cstruct}}}}"}, @assertion_timeout
    end

    test "handles `extra_db_nodes: {module, function, arguments}`" do
      :mnesia.kill()

      # Init node a and write to it
      node_a = spawn_node("a")
      {:ok, _pid} = :rpc.call(node_a, Supervisor, :start_child, [Pow.Supervisor, {MnesiaCache, @default_config}])
      assert :rpc.call(node_a, :mnesia, :system_info, [:extra_db_nodes]) == []
      assert :rpc.call(node_a, :mnesia, :system_info, [:running_db_nodes]) == [node_a]

      # Join cluster with node b
      node_b = spawn_node("b")
      config = @default_config ++ [extra_db_nodes: {Node, :list, []}]
      {:ok, _pid} = :rpc.call(node_b, Supervisor, :start_child, [Pow.Supervisor, {MnesiaCache, config}])
      assert :rpc.call(node_b, :mnesia, :system_info, [:extra_db_nodes]) == [node_a]
      assert :rpc.call(node_b, :mnesia, :system_info, [:running_db_nodes]) == [node_a, node_b]
    end
  end

  defp spawn_node(sname) do
    fn -> init_node(sname) end
    |> Task.async()
    |> Task.await(30_000)
  end

  defp init_node(sname) do
    {:ok, node} = :slave.start('127.0.0.1', String.to_atom(sname), '-loader inet -hosts 127.0.0.1 -setcookie #{:erlang.get_cookie()}')

    # Copy code
    rpc(node, :code, :add_paths, [:code.get_path()])

    # Copy all config
    for {app_name, _, _} <- Application.loaded_applications() do
      for {key, val} <- Application.get_all_env(app_name) do
        rpc(node, Application, :put_env, [app_name, key, val])
      end
    end

    # Set mnesia directory
    rpc(node, Application, :put_env, [:mnesia, :dir, 'tmp/mnesia_multi/#{sname}'])

    # Start all apps
    rpc(node, Application, :ensure_all_started, [:mix])
    rpc(node, Mix, :env, [Mix.env()])
    for {app_name, _, _} <- Application.started_applications() do
      rpc(node, Application, :ensure_all_started, [app_name])
    end

    # Remove logger to prevent logs
    rpc(node, Logger, :remove_backend, [:console])

    node
  end

  defp rpc(node, module, function, args) do
    :rpc.block_call(node, module, function, args)
  end

  defp disconnect(node_a, node_b) do
    true = :rpc.call(node_a, Node, :disconnect, [node_b])
    :timer.sleep(50)
  end

  defp connect(node_a, node_b) do
    true = :rpc.call(node_a, Node, :connect, [node_b])
    :timer.sleep(500)
  end

  defp subscribe_log_events(node) do
    {:module, LogGenEventerSubscriber, _, _} = rpc(node, Module, :create, [LogGenEventerSubscriber,
      quote do
        def init(__MODULE__), do: {:ok, %{}}

        def handle_event({level, _gl, {Logger, msg, _ts, meta}}, state) do
          {:log, _, _, _} = :rpc.block_call(:"master@127.0.0.1", Kernel, :send, [:test_process, {:log, node(), level, to_string(msg)}])

          {:ok, state}
        end
      end, Macro.Env.location(__ENV__)])

    :ok = rpc(node, :gen_event, :add_sup_handler, [Logger, LogGenEventerSubscriber, LogGenEventerSubscriber])
  end

  defp flush_process_mailbox() do
    receive do
      _ -> flush_process_mailbox()
    after
      0 -> nil
    end
  end

  defp reset_unsplit_trigger_inconsistent_database(node, cluster_node, config) do
    :ok = :rpc.block_call(node, Supervisor, :terminate_child, [Pow.Supervisor, MnesiaCache.Unsplit])
    :ok = :rpc.block_call(node, Supervisor, :delete_child, [Pow.Supervisor, MnesiaCache.Unsplit])
    {:ok, pid} = :rpc.block_call(node, Supervisor, :start_child, [Pow.Supervisor, {MnesiaCache.Unsplit, config}])
    :rpc.call(node, Kernel, :send, [pid, {:mnesia_system_event, {:inconsistent_database, nil, cluster_node}}])
  end

  # TODO: Remove by 1.1.0
  describe "backwards compatible" do
    setup do
      :mnesia.kill()

      File.rm_rf!("tmp/mnesia")
      File.mkdir_p!("tmp/mnesia")

      :ok
    end

    test "removes old entries" do
      :ok = :mnesia.start()
      {:atomic, :ok} = :mnesia.change_table_copy_type(:schema, node(), :disc_copies)
      {:atomic, :ok} = :mnesia.create_table(MnesiaCache, type: :set, disc_copies: [node()])
      :ok = :mnesia.wait_for_tables([MnesiaCache], :timer.seconds(15))

      key = "#{@default_config[:namespace]}:key1"

      :ok = :mnesia.dirty_write({MnesiaCache, key, {"key1", "test", @default_config, :os.system_time(:millisecond) + 100}})

      :stopped = :mnesia.stop()

      assert CaptureLog.capture_log(fn ->
        start(@default_config)
      end) =~ "[warn]  Deleting old record in the mnesia cache: \"pow:test:key1\""

      assert :mnesia.dirty_read({MnesiaCache, key}) == []
    end
  end
end
