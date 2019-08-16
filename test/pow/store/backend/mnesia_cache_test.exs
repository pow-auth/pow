defmodule Pow.Store.Backend.MnesiaCacheTest do
  use ExUnit.Case
  doctest Pow.Store.Backend.MnesiaCache

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

      start_supervised!(MnesiaCache)

      :ok
    end

    test "can put, get and delete records with persistent storage" do
      assert MnesiaCache.get(@default_config, "key") == :not_found

      MnesiaCache.put(@default_config, "key", "value")
      :timer.sleep(100)
      assert MnesiaCache.get(@default_config, "key") == "value"

      restart(@default_config)

      assert MnesiaCache.get(@default_config, "key") == "value"

      MnesiaCache.delete(@default_config, "key")
      :timer.sleep(100)
      assert MnesiaCache.get(@default_config, "key") == :not_found
    end

    test "with no `:ttl` opt" do
      assert_raise ConfigError, "`:ttl` configuration option is required for Pow.Store.Backend.MnesiaCache", fn ->
        MnesiaCache.put([namespace: "pow:test"], "key", "value")
      end
    end

    test "fetch keys" do
      MnesiaCache.put(@default_config, "key1", "value")
      MnesiaCache.put(@default_config, "key2", "value")
      :timer.sleep(100)

      assert MnesiaCache.keys(@default_config) == ["key1", "key2"]
    end

    test "records auto purge with persistent storage" do
      config = Config.put(@default_config, :ttl, 100)

      MnesiaCache.put(config, "key", "value")
      :timer.sleep(50)
      assert MnesiaCache.get(config, "key") == "value"
      :timer.sleep(100)
      assert MnesiaCache.get(config, "key") == :not_found

      MnesiaCache.put(config, "key", "value")
      :timer.sleep(50)
      restart(config)
      assert MnesiaCache.get(config, "key") == "value"
      :timer.sleep(100)
      assert MnesiaCache.get(config, "key") == :not_found
    end
  end

  defp restart(config) do
    :ok = stop_supervised(MnesiaCache)
    :mnesia.stop()

    start_supervised!({MnesiaCache, config})
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

    test "will join cluster" do
      # Init node a and write to it
      node_a = spawn_node("a")
      {:ok, _pid} = :rpc.call(node_a, MnesiaCache, :start_link, [@default_config])
      assert :rpc.call(node_a, :mnesia, :table_info, [MnesiaCache, :storage_type]) == :disc_copies
      assert :rpc.call(node_a, :mnesia, :system_info, [:extra_db_nodes]) == []
      assert :rpc.call(node_a, :mnesia, :system_info, [:running_db_nodes]) == [node_a]
      assert :rpc.call(node_a, MnesiaCache, :put, [@default_config, "key_set_on_a", "value"])
      :timer.sleep(50)
      assert :rpc.call(node_a, MnesiaCache, :get, [@default_config, "key_set_on_a"]) == "value"

      # Join cluster with node b and ensures that it has node a data
      node_b = spawn_node("b")
      config = @default_config ++ [extra_db_nodes: [node_a]]
      {:ok, _pid} = :rpc.call(node_b, MnesiaCache, :start_link, [config])
      assert :rpc.call(node_b, :mnesia, :table_info, [MnesiaCache, :storage_type]) == :disc_copies
      assert :rpc.call(node_b, :mnesia, :system_info, [:extra_db_nodes]) == [node_a]
      assert :rpc.call(node_b, :mnesia, :system_info, [:running_db_nodes]) == [node_a, node_b]
      assert :rpc.call(node_b, MnesiaCache, :get, [@default_config, "key_set_on_a"]) == "value"

      # Write to node b can be fetched on node a
      assert :rpc.call(node_b, MnesiaCache, :put, [@default_config, "key_set_on_b", "value"])
      :timer.sleep(50)
      assert :rpc.call(node_a, MnesiaCache, :get, [@default_config, "key_set_on_b"]) == "value"

      # Set short TTL on node a
      config = Config.put(@default_config, :ttl, 150)
      assert :rpc.call(node_a, MnesiaCache, :put, [config, "short_ttl_key_set_on_a", "value"])
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
      assert :rpc.call(node_b, MnesiaCache, :put, [config, "short_ttl_key_2_set_on_b", "value"])
      :timer.sleep(50)
      assert :rpc.call(node_b, MnesiaCache, :get, [config, "short_ttl_key_2_set_on_b"]) == "value"

      # Start node a and join cluster
      startup_timestamp = :os.system_time(:millisecond)
      node_a = spawn_node("a")
      config = @default_config ++ [extra_db_nodes: [node_b]]
      {:ok, _pid} = :rpc.call(node_a, MnesiaCache, :start_link, [config])
      assert :rpc.call(node_b, :mnesia, :system_info, [:running_db_nodes]) == [node_a, node_b]
      assert :rpc.call(node_b, MnesiaCache, :get, [config, "short_ttl_key_2_set_on_b"]) == "value"
      assert :rpc.call(node_a, MnesiaCache, :get, [config, "short_ttl_key_2_set_on_b"]) == "value"

      # Stop node b
      :ok = :slave.stop(node_b)

      # Node a invalidates short TTL value written on node b
      startup_time = :os.system_time(:millisecond) - startup_timestamp
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
      assert :rpc.call(node_a, MnesiaCache, :put, [@default_config, "key_1", "value"])
      :timer.sleep(50)
      assert :rpc.call(node_a, MnesiaCache, :get, [@default_config, "key_1"]) == "value"
      assert :rpc.call(node_b, MnesiaCache, :get, [@default_config, "key_1"]) == "value"

      # Disconnect the nodes
      disconnect(node_b, node_a)

      # Continue writing on node a and node b
      assert :rpc.call(node_a, MnesiaCache, :put, [@default_config, "key_1", "a"])
      assert :rpc.call(node_a, MnesiaCache, :put, [@default_config, "key_1_a", "value"])
      assert :rpc.call(node_b, MnesiaCache, :put, [@default_config, "key_1", "b"])
      assert :rpc.call(node_b, MnesiaCache, :put, [@default_config, "key_1_b", "value"])
      :timer.sleep(50)
      assert :rpc.call(node_a, MnesiaCache, :get, [@default_config, "key_1"]) == "a"
      assert :rpc.call(node_a, MnesiaCache, :get, [@default_config, "key_1_a"]) == "value"
      assert :rpc.call(node_b, MnesiaCache, :get, [@default_config, "key_1"]) == "b"
      assert :rpc.call(node_b, MnesiaCache, :get, [@default_config, "key_1_b"]) == "value"

      # Reconnect
      connect(node_b, node_a)

      # Node a wins recovery and node b purges its data
      assert :rpc.call(node_a, :mnesia, :system_info, [:running_db_nodes]) == [node_b, node_a]
      assert :rpc.call(node_a, MnesiaCache, :get, [@default_config, "key_1"]) == "a"
      assert :rpc.call(node_b, MnesiaCache, :get, [@default_config, "key_1"]) == "a"
      assert :rpc.call(node_a, MnesiaCache, :get, [@default_config, "key_1_b"]) == :not_found
      assert :rpc.call(node_b, MnesiaCache, :get, [@default_config, "key_1_a"]) == "value"

      # Isolated tables still works on both nodes
      assert :rpc.call(node_a, :mnesia, :dirty_read, [{:node_a_table, :key}]) == [{:node_a_table, :key, "a"}]
      assert :rpc.call(node_b, :mnesia, :dirty_read, [{:node_b_table, :key}]) == [{:node_b_table, :key, "b"}]

      # Shared tables unrelated to Pow can't reconnect
      {:atomic, :ok} = :rpc.call(node_a, :mnesia, :create_table, [:shared, [disc_copies: [node_a]]])
      {:atomic, :ok} = :rpc.call(node_b, :mnesia, :add_table_copy, [:shared, node_b, :disc_copies])
      disconnect(node_b, node_a)
      connect(node_b, node_a)
      assert :rpc.call(node_a, :mnesia, :system_info, [:running_db_nodes]) == [node_a]

      # Can't reconnect if table not defined in flush table
      :rpc.call(node_a, MnesiaCache.Unsplit, :__heal__, [node_b, [flush_tables: [:unrelated]]])
      assert :rpc.call(node_a, :mnesia, :system_info, [:running_db_nodes]) == [node_a]

      # Can reconnect if `:flush_tables` is set as `:all` or with table
      :rpc.call(node_a, MnesiaCache.Unsplit, :__heal__, [node_b, [flush_tables: [:shared]]])
      assert :rpc.call(node_a, :mnesia, :system_info, [:running_db_nodes]) == [node_b, node_a]
      disconnect(node_b, node_a)
      connect(node_b, node_a)
      assert :rpc.call(node_a, :mnesia, :system_info, [:running_db_nodes]) == [node_a]
      :rpc.call(node_a, MnesiaCache.Unsplit, :__heal__, [node_b, [flush_tables: :all]])
      assert :rpc.call(node_a, :mnesia, :system_info, [:running_db_nodes]) == [node_b, node_a]
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

    # Remove logger
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
end
