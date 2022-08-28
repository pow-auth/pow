defmodule Pow.Store.Backend.MnesiaCache.Unsplit do
  @moduledoc """
  GenServer that handles network split recovery for
  `Pow.Store.Backend.MnesiaCache`.

  This should be run on node(s) that has the `Pow.Store.Backend.MnesiaCache`
  GenServer running. It'll subscribe to the Mnesia system messages, and listen
  for `:inconsistent_database` system events. The first node to set the global
  lock will find the island with the oldest node and restore that nodes table
  into all the partitioned nodes.

  If a table unrelated to Pow is also affected, an error will be logged and the
  network will stay partitioned. If you don't mind potential data loss for any
  of your tables in Mnesia, you can set `flush_tables: :all` to restore all the
  affected tables from the oldest node in the cluster.

  For better control, you can use
  [`unsplit`](https://github.com/uwiger/unsplit) instead of this module.

  ## Usage

  To start the GenServer, add it to your application `start/2` function:

      defmodule MyApp.Application do
        use Application

        def start(_type, _args) do
          children = [
            MyApp.Repo,
            MyAppWeb.Endpoint,
            {Pow.Store.Backend.MnesiaCache, extra_db_nodes: {Node, :list, []}},
            Pow.Store.Backend.MnesiaCache.Unsplit
          ]

          opts = [strategy: :one_for_one, name: MyAppWeb.Supervisor]
          Supervisor.start_link(children, opts)
        end

        # ...
      end

  ## Auto initialize cluster

  If nodes are lazily connected a race condition can occur in which the
  `Pow.Store.Backend.MnesiaCache` is running on each node without being
  connected in a Mnesia cluster.

  To ensure that cluster will automatically initialize,
  `Pow.Store.Backend.MnesiaCache.Unsplit` will reset the most recent node's
  Mnesia schema when connecting to another node or a cluster. This will only
  occur if the Mnesia node has never been connected to the other node(s) and
  the other node currently runs the Mnesia cache GenServer.

  The `Pow.Store.Backend.MnesiaCache` GenServer will be restarted, using the same
  `:extra_db_nodes` configuration as when it was first initialized. Therefor
  it's important that a MFA is used like `{Node, :list, []}` for the auto
  initialization to succeed.

  Please be aware the reset of the Mnesia node will result in data loss for the
  node.

  ## Strategy for multiple libraries using the Mnesia instance

  It's strongly recommended to take into account any libraries that will be
  using Mnesia for storage before using this module.

  A common example would be a job queue, where a potential solution to prevent
  data loss is to simply keep the job queue table on only one server instead of
  replicating it among all nodes. When a network partition occurs, it won't be
  part of the affected tables so this module can self-heal without the job
  queue table set in `:flush_tables`.

  There may still be data loss if nodes are lazily connected. Please read the
  "Auto initialize cluster" section above.

  ## Initialization options

    * `:flush_tables` - list of tables that may be flushed and restored from
      the oldest node in the cluster. Defaults to `false` when only the
      MnesiaCache table will be flushed. Use `:all` if you want to flush all
      affected tables. Be aware that this may cause data loss.

    * `:auto_initialize_cluster` - a boolean value to automatically initialize
      the Mnesia cluster by resetting the node Mnesia schema when new nodes are
      connected, defaults to `true`.
  """
  use GenServer
  require Logger

  alias Pow.Config

  @mnesia_cache_tab Pow.Store.Backend.MnesiaCache

  @spec start_link(Config.t()) :: GenServer.on_start()
  def start_link(config) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  # Callbacks

  @impl true
  def init(config) do
    {:ok, _node} = :mnesia.subscribe(:system)
    :ok = :net_kernel.monitor_nodes(true)

    {:ok, %{config: config}}
  end

  @impl true
  def handle_info({:nodeup, node}, %{config: config} = state) do
    :global.trans({__MODULE__, self()}, fn -> autoinit(node, config) end)

    {:noreply, state}
  end

  def handle_info({:mnesia_system_event, {:inconsistent_database, _context, node}}, %{config: config} = state) do
    :global.trans({__MODULE__, self()}, fn -> autoheal(node, config) end)

    {:noreply, state}
  end

  def handle_info({:mnesia_system_event, _event}, state), do: {:noreply, state}
  def handle_info({:nodedown, _node}, state), do: {:noreply, state}

  defp autoinit(node, config) do
    cond do
      Config.get(config, :auto_initialize_cluster, true) != true ->
        :ok

      node in :mnesia.system_info(:db_nodes) ->
        :ok

      is_nil(:rpc.call(node, Process, :whereis, [Pow.Store.Backend.MnesiaCache])) ->
        :ok

      true ->
        do_autoinit(node, config)
    end
  end

  defp do_autoinit(node, config) do
    local_cluster_nodes = :mnesia.system_info(:running_db_nodes)
    remote_cluster_nodes = :rpc.call(node, :mnesia, :system_info, [:running_db_nodes])

    case {local_cluster_nodes, remote_cluster_nodes} do
      {[_local_node], [_remote_node]} ->
        Logger.info("Connection to #{inspect node} established with no mnesia cluster found for either #{inspect node()} or #{inspect node}")

        {local_node_uptime, _} = :erlang.statistics(:wall_clock)
        {remote_node_uptime, _} = :rpc.call(node, :erlang, :statistics, [:wall_clock])

        if local_node_uptime < remote_node_uptime do
          reset_node(node, config)
        else
          Logger.info("Skipping reset for #{inspect node()} as #{inspect node} is the most recent node")
        end

      {[_local_node], _remote_cluster_nodes} ->
        Logger.info("Connection to #{inspect node} established with no mnesia cluster running on #{inspect node()}")
        reset_node(node, config)

      {_local_cluster_nodes, _remote_cluster_node_or_nodes} ->
        Logger.info("Connection to #{inspect node} established with #{inspect node()} already being part of a mnesia cluster")
    end
  end

  defp reset_node(node, _config) do
    Logger.warn("Resetting mnesia on #{inspect node()} and restarting the mnesia cache to connect to #{inspect node}")

    :mnesia.stop()
    :mnesia.delete_schema([node()])
    Process.exit(Process.whereis(Pow.Store.Backend.MnesiaCache), :kill)
  end

  defp autoheal(node, config) do
    :running_db_nodes
    |> :mnesia.system_info()
    |> Enum.member?(node)
    |> case do
      true ->
        Logger.info("The node #{inspect node} has already been healed and joined the mnesia cluster")

        :ok

      false ->
        Logger.warn("Detected a netsplit in the mnesia cluster with node #{inspect node}")

        heal(node, config)
    end
  end

  defp heal(node, config) do
    node
    |> affected_tables()
    |> force_reload(node, config)
  end

  defp affected_tables(node) do
    :tables
    |> :mnesia.system_info()
    |> List.delete(:schema)
    |> List.foldl([], fn table, acc ->
      nodes     = get_all_nodes_for_table(table)
      is_shared = node in nodes && node() in nodes

      case is_shared do
        true  -> [table | acc]
        false -> acc
      end
    end)
  end

  defp get_all_nodes_for_table(table) do
    [:ram_copies, :disc_copies, :disc_only_copies]
    |> Enum.map(&:mnesia.table_info(table, &1))
    |> Enum.concat()
  end

  defp force_reload(tables, node, config) do
    flushable_tables =
      case Config.get(config, :flush_tables, false) do
        false  -> [@mnesia_cache_tab]
        :all   -> tables
        tables -> Enum.uniq([@mnesia_cache_tab | tables])
      end

    maybe_force_reload(tables, flushable_tables, node)
  end

  defp maybe_force_reload(tables, flushable_tables, node) do
    case tables -- flushable_tables do
      [] ->
        do_force_reload(tables, node)

      unflushable_tables ->
        Logger.error("Can't force reload unexpected tables #{inspect unflushable_tables} to heal #{inspect node}")

        {:error, {:unexpected_tables, tables}}
    end
  end

  defp do_force_reload(tables, node) do
    [master_nodes, nodes] = sorted_cluster_islands(node)

    for node <- nodes do
      :stopped = :rpc.call(node, :mnesia, :stop, [])
      for table <- tables, do: :ok = :rpc.call(node, :mnesia, :set_master_nodes, [table, master_nodes])
      :ok = :rpc.block_call(node, :mnesia, :start, [])
      :ok = :rpc.call(node, :mnesia, :wait_for_tables, [tables, :timer.seconds(15)])

      Logger.info("The node #{inspect node} has been healed and joined the mnesia cluster #{inspect master_nodes}")
    end

    :ok
  end

  defp sorted_cluster_islands(node) do
    island_a    = :mnesia.system_info(:running_db_nodes)
    island_b    = :rpc.call(node, :mnesia, :system_info, [:running_db_nodes])

    Enum.sort([island_a, island_b], &older?/2)
  end

  defp older?(island_a, island_b) do
    all_nodes    = get_all_nodes_for_table(@mnesia_cache_tab)
    island_nodes = Enum.concat(island_a, island_b)

    oldest_node = all_nodes |> Enum.reverse() |> Enum.find(&(&1 in island_nodes))

    oldest_node in island_a
  end
end
