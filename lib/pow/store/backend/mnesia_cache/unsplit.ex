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

  To start the GenServer, add it to your application `start/2` method:

      defmodule MyApp.Application do
        use Application

        def start(_type, _args) do
          children = [
            MyApp.Repo,
            MyAppWeb.Endpoint,
            {Pow.Store.Backend.MnesiaCache, extra_db_nodes: Node.list()},
            Pow.Store.Backend.MnesiaCache.Unsplit
          ]

          opts = [strategy: :one_for_one, name: MyAppWeb.Supervisor]
          Supervisor.start_link(children, opts)
        end

        # ...
      end

  ## Strategy for multiple libraries using the Mnesia instance

  It's strongly recommended to take into account any libraries that will be
  using Mnesia for storage before using this module.

  A common example would be a job queue, where a potential solution to prevent
  data loss is to simply keep the job queue table on only one server instead of
  replicating it among all nodes. When a network partition occurs, it won't be
  part of the affected tables so this module can self-heal without the job
  queue table set in `:flush_tables`.

  ## Initialization options

    * `:flush_tables` - list of tables that may be flushed and restored from
      the oldest node in the cluster. Defaults to `false` when only the
      MnesiaCache table will be flushed. Use `:all` if you want to flush all
      affected tables. Be aware that this may cause data loss.
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
  @spec init(Config.t()) :: {:ok, map()}
  def init(config) do
    :mnesia.subscribe(:system)

    {:ok, %{config: config}}
  end

  @impl true
  @spec handle_info({:mnesia_system_event, {:inconsistent_database, any(), any()}} | any(), map()) :: {:noreply, map()}
  def handle_info({:mnesia_system_event, {:inconsistent_database, _context, node}}, %{config: config} = state) do
    :global.trans({__MODULE__, self()}, fn -> autoheal(node, config) end)

    {:noreply, state}
  end

  @impl true
  def handle_info(_event, state) do
    {:noreply, state}
  end

  @doc false
  def __heal__(node, config), do: autoheal(node, config)

  defp autoheal(node, config) do
    :running_db_nodes
    |> :mnesia.system_info()
    |> Enum.member?(node)
    |> case do
      true ->
        Logger.info("[#{inspect __MODULE__}] #{inspect node} has already healed and joined #{inspect node()}")

        :ok

      false ->
        Logger.warn("[#{inspect __MODULE__}] Detected netsplit on #{inspect node}")

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
      is_shared = Enum.member?(nodes, node) && Enum.member?(nodes, node())

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
        Logger.error("[#{inspect __MODULE__}] Can't force reload unexpected tables #{inspect unflushable_tables}")

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

      Logger.info("[#{inspect __MODULE__}] #{inspect node} has been healed and joined #{inspect master_nodes}")
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

    oldest_node = all_nodes |> Enum.reverse() |> Enum.find(&Enum.member?(island_nodes, &1))

    Enum.member?(island_a, oldest_node)
  end
end
