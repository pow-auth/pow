defmodule Pow.Store.Backend.MnesiaCacheTest do
  use ExUnit.Case
  doctest Pow.Store.Backend.MnesiaCache

  alias ExUnit.CaptureLog
  alias Pow.{Config, Config.ConfigError, Store.Backend.MnesiaCache}

  @default_config [namespace: "pow:test", ttl: :timer.hours(1)]

  @test_node :"test@127.0.0.1"

  setup_all do
    # Turn node into a distributed node with the given long name
    {:ok, _pid} = :net_kernel.start([@test_node])

    :ok
  end

  describe "single node" do
    setup do
      # Clear Mnesia
      :mnesia.stop()
      File.rm_rf!("tmp/mnesia")
      File.mkdir_p!("tmp/mnesia")

      start(@default_config)

      :ok
    end

    test "can put, get and delete records with persistent storage" do
      assert MnesiaCache.get(@default_config, "key") == :not_found

      MnesiaCache.put(@default_config, {"key", "value"})
      assert MnesiaCache.get(@default_config, "key") == "value"

      restart(@default_config)

      assert MnesiaCache.get(@default_config, "key") == "value"

      MnesiaCache.delete(@default_config, "key")
      assert MnesiaCache.get(@default_config, "key") == :not_found
    end

    test "with `writes: :async` config option" do
      config = Keyword.put(@default_config, :writes, :async)

      MnesiaCache.put(config, {"key", "value"})
      assert MnesiaCache.get(config, "key") == :not_found
      assert_receive {:mnesia_table_event, {:write, _, _}} # Wait for async write
      assert MnesiaCache.get(config, "key") == "value"

      MnesiaCache.delete(config, "key")
      assert MnesiaCache.get(config, "key") == "value"
      assert_receive {:mnesia_table_event, {:delete, _, _}} # Wait for async delete
      assert MnesiaCache.get(config, "key") == :not_found
    end

    test "can put multiple records" do
      assert MnesiaCache.get(@default_config, "key") == :not_found

      MnesiaCache.put(@default_config, [{"key1", "1"}, {"key2", "2"}])
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

      assert MnesiaCache.all(@default_config, :_) ==  [{"key1", "value"}, {"key2", "value"}]
      assert MnesiaCache.all(@default_config, ["namespace", :_]) ==  [{["namespace", "key"], "value"}]
    end

    test "records auto purge with persistent storage" do
      config = Config.put(@default_config, :ttl, 50)

      MnesiaCache.put(config, {"key", "value"})
      MnesiaCache.put(config, [{"key1", "1"}, {"key2", "2"}])
      flush_process_mailbox() # Ignore sync write messages
      assert MnesiaCache.get(config, "key") == "value"
      assert MnesiaCache.get(config, "key1") == "1"
      assert MnesiaCache.get(config, "key2") == "2"
      assert_receive {:mnesia_table_event, {:delete, _, _}} # Wait for TTL reached
      assert_receive {:mnesia_table_event, {:delete, _, _}} # Wait for TTL reached
      assert_receive {:mnesia_table_event, {:delete, _, _}} # Wait for TTL reached
      assert MnesiaCache.get(config, "key") == :not_found
      assert MnesiaCache.get(config, "key1") == :not_found
      assert MnesiaCache.get(config, "key2") == :not_found

      # After restart
      MnesiaCache.put(config, {"key", "value"})
      MnesiaCache.put(config, [{"key1", "1"}, {"key2", "2"}])
      flush_process_mailbox() # Ignore sync write messages
      restart(config)
      assert MnesiaCache.get(config, "key") == "value"
      assert MnesiaCache.get(config, "key1") == "1"
      assert MnesiaCache.get(config, "key2") == "2"
      assert_receive {:mnesia_table_event, {:delete, _, _}} # Wait for TTL reached
      assert_receive {:mnesia_table_event, {:delete, _, _}} # Wait for TTL reached
      assert_receive {:mnesia_table_event, {:delete, _, _}} # Wait for TTL reached
      assert MnesiaCache.get(config, "key") == :not_found
      assert MnesiaCache.get(config, "key1") == :not_found
      assert MnesiaCache.get(config, "key2") == :not_found

      # After record expiration updated reschedules
      MnesiaCache.put(config, {"key", "value"})
      :mnesia.dirty_write({MnesiaCache, ["pow:test", "key"], {"value", :os.system_time(:millisecond) + 150}})
      flush_process_mailbox() # Ignore sync write messages
      assert_receive {:mnesia_system_event, {:mnesia_user, {:reschedule_invalidator, {_, _, _}}}} # Wait for reschedule event
      assert MnesiaCache.get(config, "key") == "value"
      assert_receive {:mnesia_table_event, {:delete, _, _}}, 150 # Wait for TTL reached
      assert MnesiaCache.get(config, "key") == :not_found
    end

    test "when initiated with unexpected records" do
      :mnesia.dirty_write({MnesiaCache, ["pow:test", "key"], :invalid_value})

      assert CaptureLog.capture_log([format: "[$level]  $message", colors: [enabled: false]], fn ->
        restart(@default_config)
      end) =~ ~r/\[(warn|warning|)\]  #{Regex.escape("Found an unexpected record in the mnesia cache, please delete it: [\"pow:test\", \"key\"]")}/
    end

    # TODO: Remove by 1.1.0
    test "backwards compatible" do
      assert_capture_io_eval(quote do
        assert MnesiaCache.put(unquote(@default_config), "key", "value") == :ok
      end, "Pow.Store.Backend.MnesiaCache.put/3 is deprecated. Use `put/2` instead")

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
    :mnesia.subscribe(:system)
    :mnesia.subscribe({:table, MnesiaCache, :simple})
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
        stop_node(:'a@127.0.0.1')
        stop_node(:'b@127.0.0.1')
        stop_node(:'c@127.0.0.1')
      end)

      :ok
    end

    @assertion_timeout 500

    test "will join cluster" do
      # Init node a and write to it
      node_a = spawn_node("a")
      start_mnesia_cache(node_a, @default_config)
      expected_msg = "Mnesia cluster initiated on #{inspect node_a}"
      assert_receive {{Logger, ^node_a}, {:info, ^expected_msg}}, @assertion_timeout
      assert :rpc.call(node_a, :mnesia, :table_info, [MnesiaCache, :storage_type]) == :disc_copies
      assert :rpc.call(node_a, :mnesia, :system_info, [:extra_db_nodes]) == []
      assert :rpc.call(node_a, :mnesia, :system_info, [:running_db_nodes]) == [node_a]
      assert :rpc.call(node_a, MnesiaCache, :put, [@default_config, {"key_set_on_a", "value"}])
      assert :rpc.call(node_a, MnesiaCache, :get, [@default_config, "key_set_on_a"]) == "value"

      # Join cluster with node b and ensures that it has node a data
      flush_process_mailbox()
      node_b = spawn_node("b")
      start_mnesia_cache(node_b, @default_config ++ [extra_db_nodes: [node_a]])
      expected_msg = "Joined mnesia cluster nodes [#{inspect node_a}] for #{inspect node_b}"
      assert_receive {{Logger, ^node_b}, {:info, ^expected_msg}}, @assertion_timeout
      assert :rpc.call(node_b, :mnesia, :table_info, [MnesiaCache, :storage_type]) == :disc_copies
      assert :rpc.call(node_b, :mnesia, :system_info, [:extra_db_nodes]) == [node_a]
      assert :rpc.call(node_b, :mnesia, :system_info, [:running_db_nodes]) == [node_a, node_b]
      assert :rpc.call(node_b, MnesiaCache, :get, [@default_config, "key_set_on_a"]) == "value"

      # Write to node b can be fetched on node a
      assert :rpc.call(node_b, MnesiaCache, :put, [@default_config, {"key_set_on_b", "value"}])
      assert :rpc.call(node_a, MnesiaCache, :get, [@default_config, "key_set_on_b"]) == "value"

      # Set short TTL on node a
      flush_process_mailbox()
      config = Config.put(@default_config, :ttl, 100)
      assert :rpc.call(node_a, MnesiaCache, :put, [config, {"short_ttl_key_set_on_a", "value"}])
      assert_receive {{:mnesia, ^node_b}, {:mnesia_system_event, {:mnesia_user, {:refresh_invalidators, {_, _}}}}}

      # Stop node a
      flush_process_mailbox()
      :ok = stop_node(node_a)
      assert_receive {{:node, ^node_b}, {:nodedown, ^node_a}}
      assert_receive {{:mnesia, ^node_b}, {:mnesia_system_event, {:mnesia_down, ^node_a}}}
      assert :rpc.call(node_b, :mnesia, :system_info, [:running_db_nodes]) == [node_b]

      # Ensure that node b invalidates with TTL set on node a
      assert :rpc.call(node_b, MnesiaCache, :get, [config, "short_ttl_key_set_on_a"]) == "value"
      assert_receive {{:mnesia, ^node_b}, {:mnesia_table_event, {:delete, {MnesiaCache, [_, "short_ttl_key_set_on_a"]}, _}}}, @assertion_timeout
      assert :rpc.call(node_b, MnesiaCache, :get, [config, "short_ttl_key_set_on_a"]) == :not_found

      # Start node a but not mnesia yet before we test cross node TTL
      flush_process_mailbox()
      node_a = spawn_node("a")

      # Continue writing to node b with TTL
      config = Config.put(@default_config, :ttl, @assertion_timeout)
      assert :rpc.call(node_b, MnesiaCache, :put, [config, {"short_ttl_key_2_set_on_b", "value"}])
      assert :rpc.call(node_b, MnesiaCache, :get, [config, "short_ttl_key_2_set_on_b"]) == "value"

      # Start mnesia on node a and join cluster
      start_mnesia_cache(node_a, @default_config ++ [extra_db_nodes: [node_b]])
      expected_msg = "Joined mnesia cluster nodes [#{inspect node_b}] for #{inspect node_a}"
      assert_receive {{Logger, ^node_a}, {:info, ^expected_msg}}, @assertion_timeout
      assert :rpc.call(node_b, :mnesia, :system_info, [:running_db_nodes]) == [node_a, node_b]
      assert :rpc.call(node_b, MnesiaCache, :get, [config, "short_ttl_key_2_set_on_b"]) == "value"
      assert :rpc.call(node_a, MnesiaCache, :get, [config, "short_ttl_key_2_set_on_b"]) == "value"

      # Stop node b
      flush_process_mailbox()
      :ok = stop_node(node_b)
      assert_receive {{:node, ^node_a}, {:nodedown, ^node_b}}, @assertion_timeout

      # Node a invalidates short TTL value written on node b
      assert_receive {{:mnesia, ^node_a}, {:mnesia_table_event, {:delete, {MnesiaCache, [_, "short_ttl_key_2_set_on_b"]}, _}}}, @assertion_timeout
      assert :rpc.call(node_a, MnesiaCache, :get, [config, "short_ttl_key_2_set_on_b"]) == :not_found
    end

    test "automaticaly joins cluster with MnesiaCache.Unsplit" do
      :mnesia.kill()

      # Initialize three separate nodes
      node_a = spawn_node("a")
      node_b = spawn_node("b")
      node_c = spawn_node("c")
      disconnect(node_a, node_b)
      disconnect(node_a, node_c)
      disconnect(node_b, node_c)

      # Start the mnesia cache and unsplit on all nodes
      config = @default_config ++ [extra_db_nodes: {Node, :list, []}]

      start_mnesia_cache(node_a, config, unsplit: true)
      start_mnesia_cache(node_b, config, unsplit: true)
      start_mnesia_cache(node_c, config, unsplit: true)

      assert_receive {{Logger, node_a}, {:info, "Mnesia cluster initiated on :\"a@127.0.0.1\""}}, @assertion_timeout
      assert_receive {{Logger, node_b}, {:info, "Mnesia cluster initiated on :\"b@127.0.0.1\""}}, @assertion_timeout
      assert_receive {{Logger, node_c}, {:info, "Mnesia cluster initiated on :\"c@127.0.0.1\""}}, @assertion_timeout
      assert :rpc.call(node_a, :mnesia, :system_info, [:extra_db_nodes]) == []
      assert :rpc.call(node_b, :mnesia, :system_info, [:extra_db_nodes]) == []
      assert :rpc.call(node_c, :mnesia, :system_info, [:extra_db_nodes]) == []
      assert :rpc.call(node_a, :mnesia, :system_info, [:running_db_nodes]) == [node_a]
      assert :rpc.call(node_b, :mnesia, :system_info, [:running_db_nodes]) == [node_b]
      assert :rpc.call(node_c, :mnesia, :system_info, [:running_db_nodes]) == [node_c]

      # Connect the two most recent nodes
      flush_process_mailbox()
      connect(node_b, node_c)

      # Node b and node c will compete to be the first to set the global lock
      # TODO: Refactor to test both scenarios explicitly
      assert_receive {{Logger, node}, {type, message}}, @assertion_timeout
      case {node, type, message} do
        {^node_c, :info, "Connection to :\"b@127.0.0.1\" established with no mnesia cluster found for either :\"c@127.0.0.1\" or :\"b@127.0.0.1\""} ->
          :ok

        {^node_b, :info, "Connection to :\"c@127.0.0.1\" established with no mnesia cluster found for either :\"b@127.0.0.1\" or :\"c@127.0.0.1\""} ->
          assert_receive {{Logger, ^node_b}, {:info, "Skipping reset for :\"b@127.0.0.1\" as :\"c@127.0.0.1\" is the most recent node"}}, @assertion_timeout
          assert_receive {{Logger, ^node_c}, {:info, "Connection to :\"b@127.0.0.1\" established with no mnesia cluster found for either :\"c@127.0.0.1\" or :\"b@127.0.0.1\""}}, @assertion_timeout
      end

      assert_receive {{Logger, ^node_c}, {:warn, "Resetting mnesia on :\"c@127.0.0.1\" and restarting the mnesia cache to connect to :\"b@127.0.0.1\""}}, @assertion_timeout
      assert_receive {{Logger, ^node_c}, {:info, "Application mnesia exited: :stopped"}}, @assertion_timeout
      assert_receive {{Logger, ^node_c}, {:info, "Joined mnesia cluster nodes [:\"b@127.0.0.1\"] for :\"c@127.0.0.1\""}}, @assertion_timeout

      assert :rpc.call(node_b, :mnesia, :system_info, [:extra_db_nodes]) == []
      assert Enum.sort(:rpc.call(node_b, :mnesia, :system_info, [:running_db_nodes])) == [node_b, node_c]
      assert :rpc.call(node_c, :mnesia, :system_info, [:extra_db_nodes]) == [node_b]
      assert Enum.sort(:rpc.call(node_c, :mnesia, :system_info, [:running_db_nodes])) == [node_b, node_c]

      # connect the oldest node with cluster
      flush_process_mailbox()
      connect(node_a, node_b)

      # Node a and node b will compete to be the first to set the global lock
      # TODO: Refactor to test the two scenarios explicitly
      assert_receive {{Logger, node}, {type, message}}, @assertion_timeout
      case {node, type, message} do
        {^node_b, :info, "Connection to :\"a@127.0.0.1\" established with :\"b@127.0.0.1\" already being part of a mnesia cluster"} ->
          assert_receive {{Logger, ^node_a}, {:info, "Connection to :\"b@127.0.0.1\" established with no mnesia cluster running on :\"a@127.0.0.1\""}}, @assertion_timeout

        {^node_a, :info, "Connection to :\"b@127.0.0.1\" established with no mnesia cluster running on :\"a@127.0.0.1\""} ->
          :ok
      end

      assert_receive {{Logger, ^node_a}, {:warn, "Resetting mnesia on :\"a@127.0.0.1\" and restarting the mnesia cache to connect to :\"b@127.0.0.1\""}}, @assertion_timeout

      # Node C may have tried to heal the cluster
      # TODO: Refactor to test explicitly
      receive do
        {{Logger, ^node_c}, {:info, "Connection to :\"a@127.0.0.1\" established with :\"c@127.0.0.1\" already being part of a mnesia cluster"}} -> :ok
      after
        100 -> :ok
      end

      assert_receive {{Logger, ^node_a}, {:info, "Application mnesia exited: :stopped"}}, @assertion_timeout

      # Node C may already have connected when Node.list() is called
      # TODO: Refactor to test the two scenarios explicitly
      assert_receive {{Logger, node}, {type, message}}, @assertion_timeout
      case {node, type, message} do
        {^node_a, :info, "Joined mnesia cluster nodes [:\"b@127.0.0.1\"] for :\"a@127.0.0.1\""} ->
          :ok

        {^node_a, :info, "Joined mnesia cluster nodes [:\"b@127.0.0.1\", :\"c@127.0.0.1\"] for :\"a@127.0.0.1\""} ->
          :ok
      end

      assert :rpc.call(node_a, :mnesia, :system_info, [:extra_db_nodes]) == [node_b]
      assert Enum.sort(:rpc.call(node_a, :mnesia, :system_info, [:running_db_nodes])) == [node_a, node_b, node_c]
    end

    test "recovers from netsplit with MnesiaCache.Unsplit" do
      node_a = spawn_node("a")
      start_mnesia_cache(node_a, @default_config, unsplit: true)

      # Create isolated table on node a
      {:atomic, :ok} = :rpc.call(node_a, :mnesia, :create_table, [:node_a_table, [disc_copies: [node_a]]])
      :ok = :rpc.call(node_a, :mnesia, :wait_for_tables, [[:node_a_table], 1_000])
      :ok = :rpc.call(node_a, :mnesia, :dirty_write, [{:node_a_table, :key, "a"}])

      node_b = spawn_node("b")
      start_mnesia_cache(node_b, @default_config ++ [extra_db_nodes: [node_a]], unsplit: true)

      # Create isolated table on node b
      {:atomic, :ok} = :rpc.call(node_b, :mnesia, :create_table, [:node_b_table, [disc_copies: [node_b]]])
      :ok = :rpc.call(node_b, :mnesia, :wait_for_tables, [[:node_b_table], 1_000])
      :ok = :rpc.call(node_b, :mnesia, :dirty_write, [{:node_b_table, :key, "b"}])

      # Ensure that data writing on node a is replicated on node b
      assert :rpc.call(node_a, MnesiaCache, :put, [@default_config, {"key_1", "value"}])
      assert :rpc.call(node_a, MnesiaCache, :get, [@default_config, "key_1"]) == "value"
      assert :rpc.call(node_b, MnesiaCache, :get, [@default_config, "key_1"]) == "value"

      # Disconnect the nodes
      flush_process_mailbox()
      disconnect(node_b, node_a)
      assert_receive {{:mnesia, ^node_a}, {:mnesia_system_event, {:mnesia_down, ^node_b}}}
      assert_receive {{:mnesia, ^node_b}, {:mnesia_system_event, {:mnesia_down, ^node_a}}}

      # Continue writing on node a and node b
      assert :rpc.call(node_a, MnesiaCache, :put, [@default_config, {"key_1", "a"}])
      assert :rpc.call(node_a, MnesiaCache, :put, [@default_config, {"key_1_a", "value"}])
      assert :rpc.call(node_b, MnesiaCache, :put, [@default_config, {"key_1", "b"}])
      assert :rpc.call(node_b, MnesiaCache, :put, [@default_config, {"key_1_b", "value"}])
      assert :rpc.call(node_a, MnesiaCache, :get, [@default_config, "key_1"]) == "a"
      assert :rpc.call(node_a, MnesiaCache, :get, [@default_config, "key_1_a"]) == "value"
      assert :rpc.call(node_b, MnesiaCache, :get, [@default_config, "key_1"]) == "b"
      assert :rpc.call(node_b, MnesiaCache, :get, [@default_config, "key_1_b"]) == "value"

      # Reconnect
      flush_process_mailbox()
      connect(node_b, node_a)

      # Node a used as primary cluster and node b is purged
      assert_receive {{:mnesia, ^node_a}, {:mnesia_system_event, {:inconsistent_database, :running_partitioned_network, ^node_b}}}
      assert_receive {{Logger, _node}, {:info, "The node :\"b@127.0.0.1\" has been healed and joined the mnesia cluster [:\"a@127.0.0.1\"]"}}, @assertion_timeout
      assert_receive {{Logger, _node}, {:warn, "Detected a netsplit in the mnesia cluster with node " <> _reported_node}}, @assertion_timeout
      assert :rpc.call(node_a, :mnesia, :system_info, [:running_db_nodes]) == [node_b, node_a]
      assert :rpc.call(node_a, MnesiaCache, :get, [@default_config, "key_1"]) == "a"
      assert :rpc.call(node_b, MnesiaCache, :get, [@default_config, "key_1"]) == "a"
      assert :rpc.call(node_a, MnesiaCache, :get, [@default_config, "key_1_b"]) == :not_found
      assert :rpc.call(node_b, MnesiaCache, :get, [@default_config, "key_1_a"]) == "value"

      # Wait until the mnesia has fully restarted on node b
      :ok = rpc(node_b, :mnesia, :wait_for_tables, [[:node_b_table], :timer.seconds(5)])

      # Isolated tables still works on both nodes
      assert :rpc.call(node_a, :mnesia, :dirty_read, [{:node_a_table, :key}]) == [{:node_a_table, :key, "a"}]
      assert :rpc.call(node_b, :mnesia, :dirty_read, [{:node_b_table, :key}]) == [{:node_b_table, :key, "b"}]

      # Shared tables unrelated to Pow can't reconnect
      {:atomic, :ok} = :rpc.call(node_a, :mnesia, :create_table, [:shared, [disc_copies: [node_a]]])
      {:atomic, :ok} = :rpc.call(node_b, :mnesia, :add_table_copy, [:shared, node_b, :disc_copies])
      flush_process_mailbox()
      disconnect(node_b, node_a)
      assert_receive {{:mnesia, ^node_a}, {:mnesia_system_event, {:mnesia_down, ^node_b}}}
      assert_receive {{:mnesia, ^node_b}, {:mnesia_system_event, {:mnesia_down, ^node_a}}}
      flush_process_mailbox()
      connect(node_b, node_a)
      assert_receive {{Logger, _node}, {:warn, "Detected a netsplit in the mnesia cluster with node " <> _reported_node}}, @assertion_timeout
      assert_receive {{Logger, _node}, {:error, "Can't force reload unexpected tables [:shared] to heal " <> _reported_node}}, @assertion_timeout
      assert :rpc.call(node_a, :mnesia, :system_info, [:running_db_nodes]) == [node_a]

      # Can't reconnect if table not defined in flush table
      flush_process_mailbox()
      reset_unsplit_trigger_inconsistent_database(node_b, node_a, flush_tables: [:unrelated])
      assert_receive {{Logger, _node}, {:warn, "Detected a netsplit in the mnesia cluster with node " <> _reported_node}}, @assertion_timeout
      assert_receive {{Logger, _node}, {:error, "Can't force reload unexpected tables [:shared] to heal " <> _reported_node}}, @assertion_timeout
      assert :rpc.call(node_b, :mnesia, :system_info, [:running_db_nodes]) == [node_b]

      # Can reconnect if `:flush_tables` is set to table
      flush_process_mailbox()
      reset_unsplit_trigger_inconsistent_database(node_b, node_a, flush_tables: [:shared])
      assert_receive {{Logger, _node}, {:warn, "Detected a netsplit in the mnesia cluster with node " <> _reported_node}}, @assertion_timeout
      assert_receive {{Logger, _node}, {:info, "The node :\"b@127.0.0.1\" has been healed and joined the mnesia cluster [:\"a@127.0.0.1\"]"}}, @assertion_timeout
      assert :rpc.call(node_a, :mnesia, :system_info, [:running_db_nodes]) == [node_b, node_a]

      # Resetting back to netsplit state
      flush_process_mailbox()
      disconnect(node_b, node_a)
      assert_receive {{:mnesia, ^node_a}, {:mnesia_system_event, {:mnesia_down, ^node_b}}}
      assert_receive {{:mnesia, ^node_b}, {:mnesia_system_event, {:mnesia_down, ^node_a}}}
      flush_process_mailbox()
      connect(node_b, node_a)
      assert_receive {{Logger, _node}, {:warn, "Detected a netsplit in the mnesia cluster with node " <> _reported_node}}, @assertion_timeout
      assert_receive {{Logger, _node}, {:error, "Can't force reload unexpected tables [:shared] to heal " <> _reported_node}}, @assertion_timeout
      assert :rpc.call(node_a, :mnesia, :system_info, [:running_db_nodes]) == [node_a]

      # Can reconnect if `:flush_tables` is set to `:all`
      flush_process_mailbox()
      reset_unsplit_trigger_inconsistent_database(node_b, node_a, flush_tables: :all)
      assert_receive {{Logger, _node}, {:warn, "Detected a netsplit in the mnesia cluster with node " <> _reported_node}}, @assertion_timeout
      assert_receive {{Logger, _node}, {:info, "The node :\"b@127.0.0.1\" has been healed and joined the mnesia cluster [:\"a@127.0.0.1\"]"}}, @assertion_timeout
      assert :rpc.call(node_a, :mnesia, :system_info, [:running_db_nodes]) == [node_b, node_a]
    end

    test "when init create cluster fails" do
      :mnesia.kill()

      # Start Mnesia with configuration error
      node_a = spawn_node("a")
      config = @default_config ++ [table_opts: [disc_copies: [:invalid_node]]]
      assert {:error, {{:create_table, {:aborted, {:not_active, Pow.Store.Backend.MnesiaCache, :invalid_node}}}, _}} = :rpc.call(node_a, Supervisor, :start_child, [Pow.Supervisor, {MnesiaCache, config}])
      assert_receive {{Logger, _node}, {:error, "Couldn't initialize mnesia cluster because: {:create_table, {:aborted, {:not_active, Pow.Store.Backend.MnesiaCache, :invalid_node}}}"}}, @assertion_timeout
    end

    test "when init join cluster fails" do
      :mnesia.kill()

      # Start Mnesia on node a uninitialized
      node_a = spawn_node("a")
      :ok = :rpc.call(node_a, :mnesia, :start, [])

      # Join cluster with node b
      node_b = spawn_node("b")
      config = @default_config ++ [extra_db_nodes: {Node, :list, []}]
      assert {:error, {{:add_table_copy, {:aborted, {:no_exists, {Pow.Store.Backend.MnesiaCache, :cstruct}}}}, _}} = :rpc.call(node_b, Supervisor, :start_child, [Pow.Supervisor, {MnesiaCache, config}])
      assert_receive {{Logger, _node}, {:error, "Couldn't join mnesia cluster because: {:add_table_copy, {:aborted, {:no_exists, {Pow.Store.Backend.MnesiaCache, :cstruct}}}}"}}, @assertion_timeout
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
    node =
      case init_node(sname) do
        {node, pid} ->
          Process.put(node, pid)

          node

        node ->
          node
      end

    listen(node, Logger)
    listen(node, :node)

    node
  end

  defp init_node(sname) do
    node_or_pid_node = start_node(sname)

    node =
      case node_or_pid_node do
        {node, _pid} -> node
        node -> node
      end

    # Copy code
    rpc(node, :code, :add_paths, [:code.get_path()])

    # Copy all config
    for {app_name, _, _} when app_name != :mnesia <- Application.loaded_applications() do
      for {key, val} <- Application.get_all_env(app_name) do
        rpc(node, Application, :put_env, [app_name, key, val])
      end
    end

    # Set mnesia directory
    rpc(node, Application, :put_env, [:mnesia, :dir, 'tmp/mnesia_multi/#{sname}'])

    # Start all apps
    rpc(node, Application, :ensure_all_started, [:mix])
    rpc(node, Mix, :env, [Mix.env()])
    for {app_name, _, _} when app_name != :mnesia <- Application.started_applications() do
      rpc(node, Application, :ensure_all_started, [app_name])
    end

    # Remove logger to prevent logs
    rpc(node, Logger, :remove_backend, [:console])

    add_listener_module(node)

    node_or_pid_node
  end

  # credo:disable-for-next-line
  defp add_listener_module(node) do
    {:module, Pow.Test.Listener, _, _} = rpc(node, Module, :create, [Pow.Test.Listener,
      quote do
        use GenServer

        def child_spec({event_mgr_ref, parent}) do
          spec = %{
            id: {__MODULE__, event_mgr_ref},
            start: {__MODULE__, :start_link, [{event_mgr_ref, parent}]}
          }

          Supervisor.child_spec(spec, [])
        end

        def start_link({event_mgr_ref, parent}) do
          GenServer.start_link(__MODULE__, {event_mgr_ref, parent})
        end

        def init({event_mgr_ref, parent}) do
          case event_mgr_ref do
            :mnesia ->
              Process.send_after(self(), :mnesia_subscribe, 1)

            :node ->
              :ok = :net_kernel.monitor_nodes(true)

            _any ->
              :ok
          end

          {:ok, {event_mgr_ref, parent}}
        end

        # Mnesia process handler
        def handle_info(:mnesia_subscribe, {event_mgr_ref, parent}) do
          case :mnesia_lib.is_running() do
            :yes ->
              :mnesia.subscribe(:system)

              # The event might already have sent before we get the chance to subscribe
              for node <- :mnesia.system_info(:extra_db_nodes),
                do: :mnesia_lib.report_system_event({:mnesia_up, node})

              :mnesia.subscribe({:table, MnesiaCache, :simple})

              # Keep track of the mnesia instance
              Process.monitor(:mnesia_controller)

            _any ->
              Process.send_after(self(), :mnesia_subscribe, 1)
          end

          {:noreply, {event_mgr_ref, parent}}
        end

        def handle_info({:DOWN, _ref, :process, {:mnesia_controller, _}, _}, state) do
          Process.send_after(self(), :mnesia_subscribe, 1)

          {:noreply, state}
        end

        # GenServer handler
        def handle_info(event, {event_mgr_ref, parent}) do
          send_event(event_mgr_ref, parent, event)

          {:noreply, {event_mgr_ref, parent}}
        end

        defp send_event(Logger, parent, {level, _gl, {Logger, msg, _ts, _meta}}) do
          send(parent, {{Logger, node()}, {level, to_string(msg)}})
        end

        defp send_event(any, parent, event) do
          send(parent, {{any, node()}, event})
        end

        # GenEvent handler
        def handle_event(event, {event_mgr_ref, parent}) do
          send_event(event_mgr_ref, parent, event)

          {:ok, {event_mgr_ref, parent}}
        end
      end, Macro.Env.location(__ENV__)])
  end

  defp start_mnesia_cache(node, config, opts \\ []) do
    rpc(node, Application, :put_all_env, [{:mnesia, Application.get_all_env(:mnesia)}])

    {:ok, _pid} = :rpc.call(node, Supervisor, :start_child, [Pow.Supervisor, {MnesiaCache, config}])

    listen(node, :mnesia)

    if opts[:unsplit], do: {:ok, _pid} = :rpc.call(node, Supervisor, :start_child, [Pow.Supervisor, MnesiaCache.Unsplit])
  end

  defp rpc(node, module, function, args) do
    :rpc.block_call(node, module, function, args)
  end

  defp listen(node, module) when module in [:mnesia, :node] do
    {:ok, _} = :rpc.call(node, Supervisor, :start_child, [Pow.Supervisor, {Pow.Test.Listener, {module, self()}}])
  end
  defp listen(node, Logger) do
    :ok = :gen_event.add_handler({Logger, node}, Pow.Test.Listener, {Logger, self()})
  end

  defp disconnect(node_a, node_b) do
    true = :rpc.call(node_a, Node, :disconnect, [node_b])
    assert_receive {{:node, ^node_a}, {:nodedown, ^node_b}}, @assertion_timeout
    assert_receive {{:node, ^node_b}, {:nodedown, ^node_a}}, @assertion_timeout
  end

  defp connect(node_a, node_b) do
    true = :rpc.call(node_a, Node, :connect, [node_b])
    assert_receive {{:node, ^node_a}, {:nodeup, ^node_b}}, @assertion_timeout
    assert_receive {{:node, ^node_b}, {:nodeup, ^node_a}}, @assertion_timeout
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

  if Code.ensure_loaded?(:peer) and function_exported?(:peer, :start, 1) do
    defp start_node(sname) do
      {:ok, pid, node} =
        :peer.start_link(%{
          name: String.to_atom(sname),
          host: '127.0.0.1',
          args: [
            '-kernel', 'prevent_overlapping_partitions', 'false'
          ]})

      {node, pid}
    end

    defp stop_node(node) do
      case Process.get(node) do
        nil ->
          :ok

        pid ->
          Process.delete(node)

          # Ensure we terminate the mnesia all processes first
          rpc(node, Supervisor, :terminate_child, [Pow.Supervisor, MnesiaCache.Unsplit])
          rpc(node, Supervisor, :terminate_child, [Pow.Supervisor, MnesiaCache])
          rpc(node, :mnesia, :stop, [])

          :peer.stop(pid)

          :ok
        end
    end
  else
    defp start_node(sname) do
      # Allow spawned nodes to fetch all code from this node
      :erl_boot_server.start([])
      {:ok, ipv4} = :inet.parse_ipv4_address('127.0.0.1')
      :erl_boot_server.add_slave(ipv4)

      {:ok, node} = :slave.start('127.0.0.1', String.to_atom(sname), '-loader inet -hosts 127.0.0.1 -setcookie #{:erlang.get_cookie()}')

      node
    end

    defp stop_node(node) do
      :slave.stop(node)
    end
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

      assert CaptureLog.capture_log([format: "[$level]  $message", colors: [enabled: false]], fn ->
        start(@default_config)
      end) =~ ~r/\[(warn|warning|)\]  #{Regex.escape("Deleting old record in the mnesia cache: \"pow:test:key1\"")}/

      assert :mnesia.dirty_read({MnesiaCache, key}) == []
    end
  end
end
