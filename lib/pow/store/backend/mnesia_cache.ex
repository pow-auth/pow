defmodule Pow.Store.Backend.MnesiaCache do
  @moduledoc """
  GenServer based key value Mnesia cache store with auto expiration.

  When the MnesiaCache starts, it will initialize invalidators for all stored
  keys using the `expire` value. If the `expire` datetime is past, it will
  call the invalidator immediately.

  Mnesia will create a `Mnesia.Node` directory in the current working directory
  to write files to. This can be changed by setting the `-mnesia dir` config:

      config :mnesia, dir: '/path/to/dir'

  The directory path should be accessible, otherwise MnesiaCache will crash on
  startup.

  `:mnesia` should be added to `:extra_applications` in `mix.exs` for it to be
  included in releases.

  ## Distribution

  The MnesiaCache is built to handle multi-node setup.

  If you initialize with `extra_db_nodes: Node.list()`, it will automatically
  connect to the cluster. You can also use MFA:
  `extra_db_nodes: {Node, :list, []}`. This is useful for when nodes are
  dynamically connected before MnesiaCache startup in the supervision tree.

  If there is no other nodes available, the data persisted to disk will be
  loaded, but if a cluster is running, the data in the existing cluster nodes
  will be loaded instead of the local data. This could potentially cause data
  loss, but is an accepted risk as all data stored by Pow should be ephemeral.

  When a cache key expires, the expiration will be verified before deletion to
  ensure that it hasn't been updated by another node. When a key is updated on
  a node, the node will ping all other nodes to refresh their invalidators so
  the new TTL is used.

  All nodes spun up will by default persist to disk. If you start up multiple
  nodes from the same physical directory you have to make sure that each node
  has a unique directory path configured. This can be done using different
  config files, or by using a system environment variable:

      config :mnesia, dir: to_charlist(System.get_env("MNESIA_DIR"))

  You can use `Pow.Store.Backend.MnesiaCache.Unsplit` to automatically recover
  from network split issues. All partitioned nodes will have their table
  flushed and reloaded from the oldest node in the cluster.

  ## Usage

  To start the GenServer, add it to your application `start/2` function:

      defmodule MyApp.Application do
        use Application

        def start(_type, _args) do
          children = [
            MyApp.Repo,
            MyAppWeb.Endpoint,
            Pow.Store.Backend.MnesiaCache
            # # Or in a distributed system:
            # {Pow.Store.Backend.MnesiaCache, extra_db_nodes: {Node, :list, []}},
            # Pow.Store.Backend.MnesiaCache.Unsplit # Recover from netsplit
          ]

          opts = [strategy: :one_for_one, name: MyAppWeb.Supervisor]
          Supervisor.start_link(children, opts)
        end

        # ...
      end

  Update configuration with `cache_store_backend: Pow.Store.Backend.MnesiaCache`.

  ## Initialization options

    * `:extra_db_nodes` - list of nodes or MFA returning a list of nodes in
      cluster to connect to.

    * `:table_opts` - options to add to table definition. This value defaults
      to `[disc_copies: [node()]]`.

    * `:timeout` - timeout value in milliseconds for how long to wait until the
      cache table has initiated. Defaults to 15 seconds.

  ## Configuration options

    * `:ttl` - integer value in milliseconds for ttl of records (required).

    * `:namespace` - string value to use for namespacing keys, defaults to
      "cache".

    * `:writes` - set to `:async` to do asynchronous writes. Defaults to
      `:sync`.
  """
  use GenServer
  alias Pow.{Config, Store.Backend.Base}

  require Logger

  @behaviour Base
  @mnesia_cache_tab __MODULE__

  @spec start_link(Base.config()) :: GenServer.on_start()
  def start_link(config) do
    # TODO: Remove by 1.1.0
    case Config.get(config, :nodes) do
      nil    -> :ok
      _nodes -> IO.warn("use of `:nodes` config value for #{inspect unquote(__MODULE__)} is no longer used")
    end

    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  @impl Base
  def put(config, record_or_records) do
    ttl = ttl!(config)

    case Config.get(config, :writes, :sync) do
      :sync ->
        records = table_insert(record_or_records, ttl, config)
        GenServer.cast(__MODULE__, {:append_validators, config, records, ttl})

      :async ->
        GenServer.cast(__MODULE__, {:cache, config, record_or_records, ttl})
    end
  end

  @impl Base
  def delete(config, key) do
    case Config.get(config, :writes, :sync) do
      :sync ->
        key = table_delete(key, config)
        GenServer.cast(__MODULE__, {:clear_invalidator, config, key})

      :async ->
        GenServer.cast(__MODULE__, {:delete, config, key})
    end
  end

  @impl Base
  def get(config, key) do
    table_get(key, config)
  end

  @impl Base
  def all(config, match) do
    table_all(match, config)
  end

  # Callbacks

  @impl GenServer
  def init(config) do
    case init_mnesia(config) do
      :ok ->
        {:ok, %{invalidators: init_invalidators(config)}}

      {:error, error} ->
        {:stop, error}
    end
  end

  @impl GenServer
  def handle_cast({:append_validators, config, records, ttl}, %{invalidators: invalidators} = state) do
    invalidators =
      Enum.reduce(records, invalidators, fn {key, _}, invalidators ->
        append_invalidator(key, invalidators, ttl, config)
      end)

    refresh_invalidators_in_cluster(config)

    {:noreply, %{state | invalidators: invalidators}}
  end

  def handle_cast({:cache, config, record_or_records, ttl}, state) do
    records = table_insert(record_or_records, ttl, config)

    handle_cast({:append_validators, config, records, ttl}, state)
  end

  def handle_cast({:clear_invalidator, _config, key}, %{invalidators: invalidators} = state) do
    invalidators = clear_invalidator(key, invalidators)

    {:noreply, %{state | invalidators: invalidators}}
  end

  def handle_cast({:delete, config, key}, state) do
    key = table_delete(key, config)

    handle_cast({:clear_invalidator, config, key}, state)
  end

  def handle_cast({:refresh_invalidators, config}, %{invalidators: invalidators} = state) do
    :mnesia.report_event({:refresh_invalidators, {@mnesia_cache_tab, {:pid, self()}}})

    {:noreply, %{state | invalidators: init_invalidators(config, invalidators)}}
  end

  @impl GenServer
  def handle_info({:invalidate, config, key}, %{invalidators: invalidators} = state) do
    invalidators = delete_or_reschedule(key, invalidators, config)

    {:noreply, %{state | invalidators: invalidators}}
  end

  defp delete_or_reschedule(key, invalidators, config) do
    config
    |> fetch(key)
    |> case do
      nil ->
        invalidators

      {_value, expire} ->
        case Kernel.max(expire - timestamp(), 0) do
          0 ->
            key
            |> table_delete(config)
            |> clear_invalidator(invalidators)

          ttl ->
            :mnesia.report_event({:reschedule_invalidator, {@mnesia_cache_tab, key, {:pid, self()}}})
            append_invalidator(key, invalidators, ttl, config)
        end
    end
  end

  defp append_invalidator(key, invalidators, ttl, config) do
    invalidators = clear_invalidator(key, invalidators)
    invalidator  = trigger_ttl(key, ttl, config)

    Map.put(invalidators, key, invalidator)
  end

  defp trigger_ttl(key, ttl, config) do
    Process.send_after(self(), {:invalidate, config, key}, ttl)
  end

  defp refresh_invalidators_in_cluster(config) do
    :running_db_nodes
    |> :mnesia.system_info()
    |> Enum.reject(& &1 == node())
    |> Enum.each(&GenServer.cast({__MODULE__, &1}, {:refresh_invalidators, config}))
  end

  defp clear_invalidator(key, invalidators) do
    case Map.get(invalidators, key) do
      nil         -> nil
      invalidator -> Process.cancel_timer(invalidator)
    end

    Map.delete(invalidators, key)
  end

  defp table_get(key, config) do
    case fetch(config, key) do
      {value, _expire} -> value
      nil              -> :not_found
    end
  end

  defp fetch(config, key) do
    mnesia_key = mnesia_key(config, key)
    case :mnesia.dirty_read({@mnesia_cache_tab, mnesia_key}) do
      [{@mnesia_cache_tab, ^mnesia_key, value}] -> value
      []                                        -> nil
    end
  end

  defp table_all(key_match, config) do
    mnesia_key_match = mnesia_key(config, key_match)

    @mnesia_cache_tab
    |> :mnesia.dirty_select([{{@mnesia_cache_tab, mnesia_key_match, :_}, [], [:"$_"]}])
    |> Enum.map(fn {@mnesia_cache_tab, key, {value, _expire}} -> {unwrap(key), value} end)
  end

  defp unwrap([_namespace, key]), do: key
  defp unwrap([_namespace | key]), do: key

  defp table_insert(record_or_records, ttl, config) do
    expire  = timestamp() + ttl
    records = List.wrap(record_or_records)

    {:atomic, _result} =
      :mnesia.sync_transaction(fn ->
        Enum.map(records, fn {key, value} ->
          mnesia_key = mnesia_key(config, key)
          value      = {value, expire}

          :mnesia.write({@mnesia_cache_tab, mnesia_key, value})
        end)
      end)

    records
  end

  defp table_delete(key, config) do
    {:atomic, key} =
      :mnesia.sync_transaction(fn ->
        mnesia_key = mnesia_key(config, key)

        :mnesia.delete({@mnesia_cache_tab, mnesia_key})

        key
      end)

    key
  end

  defp init_mnesia(config) do
    case find_active_cluster_nodes(config) do
      []    -> init_cluster(config)
      nodes -> join_cluster(config, nodes)
    end
  end

  defp find_active_cluster_nodes(config) do
    visible_nodes = Node.list()
    db_nodes      = Config.get(config, :extra_db_nodes, [])

    db_nodes =
      case db_nodes do
        {mod, fun, args} -> apply(mod, fun, args)
        nodes -> nodes
      end

    Enum.filter(db_nodes, fn node ->
      node in visible_nodes and :rpc.block_call(node, :mnesia, :system_info, [:is_running]) == :yes
    end)
  end

  defp init_cluster(config) do
    with :ok <- start_mnesia(),
         :ok <- change_table_copy_type(config),
         :ok <- create_table(config),
         :ok <- wait_for_table(config) do

      Logger.info("Mnesia cluster initiated on #{inspect node()}")

      :ok
    else
      {:error, reason} ->
        Logger.error("Couldn't initialize mnesia cluster because: #{inspect reason}")
        {:error, reason}
    end
  end

  defp join_cluster(config, cluster_nodes) do
    with :ok <- set_mnesia_master_nodes(cluster_nodes),
         :ok <- start_mnesia(),
         :ok <- connect_to_cluster(cluster_nodes),
         :ok <- change_table_copy_type(config),
         :ok <- sync_table(config, cluster_nodes),
         :ok <- wait_for_table(config) do

      Logger.info("Joined mnesia cluster nodes #{inspect cluster_nodes} for #{inspect node()}")

      :ok
    else
      {:error, reason} ->
        Logger.error("Couldn't join mnesia cluster because: #{inspect reason}")
        {:error, reason}
    end
  end

  defp start_mnesia do
    case Application.start(:mnesia) do
      {:error, {:already_started, :mnesia}} -> :ok
      :ok                                   -> :ok
      {:error, error}                       -> {:error, error}
    end
  end

  defp set_mnesia_master_nodes(cluster_nodes) do
    case :mnesia.system_info(:running_db_nodes) do
      [] ->
        :ok

      _nodes ->
        Application.stop(:mnesia)

        :mnesia.set_master_nodes(@mnesia_cache_tab, cluster_nodes)
    end
  end

  defp change_table_copy_type(config) do
    copy_type = get_copy_type(config, node())

    case :mnesia.change_table_copy_type(:schema, node(), copy_type) do
      {:atomic, :ok}                               -> :ok
      {:aborted, {:already_exists, :schema, _, _}} -> :ok
      any                                          -> {:error, {:change_table_copy_type, any}}
    end
  end

  defp get_copy_type(config, node) do
    types      = [:ram_copies, :disc_copies, :disc_only_copies]
    table_opts = Config.get(config, :table_opts, [])

    Enum.find(types, :disc_copies, fn type ->
      nodes = table_opts[type] || []

      node in nodes
    end)
  end

  defp create_table(config) do
    table_opts = Config.get(config, :table_opts, [disc_copies: [node()]])
    table_def  = Keyword.merge(table_opts, [type: :ordered_set])

    case :mnesia.create_table(@mnesia_cache_tab, table_def) do
      {:atomic, :ok}                                   -> :ok
      {:aborted, {:already_exists, @mnesia_cache_tab}} -> :ok
      any                                              -> {:error, {:create_table, any}}
    end
  end

  defp sync_table(_config, [cluster_node | _rest]) do
    copy_type = :rpc.block_call(cluster_node, :mnesia, :table_info, [@mnesia_cache_tab, :storage_type])

    case :mnesia.add_table_copy(@mnesia_cache_tab, node(), copy_type) do
      {:atomic, :ok}                      -> :ok
      {:aborted, {:already_exists, _, _}} -> :ok
      any                                 -> {:error, {:add_table_copy, any}}
    end
  end

  defp wait_for_table(config) do
    timeout = Config.get(config, :timeout, :timer.seconds(15))

    :mnesia.wait_for_tables([@mnesia_cache_tab], timeout)
  end

  defp connect_to_cluster([cluster_node | _cluster_nodes]) do
    case :mnesia.change_config(:extra_db_nodes, [cluster_node]) do
      {:ok, _}         -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp mnesia_key(config, key) do
    [namespace(config) | List.wrap(key)]
  end

  defp namespace(config), do: Config.get(config, :namespace, "cache")

  defp init_invalidators(config, existing_invalidators \\ %{}) do
    clear_all_invalidators(existing_invalidators)

    {:atomic, invalidators} =
      :mnesia.sync_transaction(fn ->
        :mnesia.foldl(fn
          {@mnesia_cache_tab, key, {_value, expire}}, invalidators when is_list(key) ->
            ttl = Enum.max([expire - timestamp(), 0])

            key
            |> unwrap()
            |> append_invalidator(invalidators, ttl, config)

          # TODO: Remove by 1.1.0
          {@mnesia_cache_tab, key, {_key, _value, _config, expire}}, invalidators when is_binary(key) and is_number(expire) ->
            Logger.warn("Deleting old record in the mnesia cache: #{inspect key}")

            :mnesia.delete({@mnesia_cache_tab, key})

            invalidators

          {@mnesia_cache_tab, key, _value}, invalidators ->
            Logger.warn("Found an unexpected record in the mnesia cache, please delete it: #{inspect key}")

            invalidators
        end,
        %{},
        @mnesia_cache_tab)
      end)

    invalidators
  end

  defp clear_all_invalidators(invalidators) do
    invalidators
    |> Map.keys()
    |> Enum.reduce(invalidators, fn key, invalidators ->
      clear_invalidator(key, invalidators)
    end)
  end

  defp timestamp, do: :os.system_time(:millisecond)

  defp ttl!(config) do
    Config.get(config, :ttl) || raise_ttl_error!()
  end

  @spec raise_ttl_error!() :: no_return()
  defp raise_ttl_error!,
    do: Config.raise_error("`:ttl` configuration option is required for #{inspect(__MODULE__)}")

  # TODO: Remove by 1.1.0
  @deprecated "Use `put/2` instead"
  @doc false
  def put(config, key, value), do: put(config, {key, value})

  # TODO: Remove by 1.1.0
  @deprecated "Use `all/2` instead"
  @doc false
  def keys(config), do: all(config, :_)
end
