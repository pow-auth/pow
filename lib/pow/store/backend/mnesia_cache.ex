defmodule Pow.Store.Backend.MnesiaCache do
  @moduledoc """
  GenServer based key value Mnesia cache store with auto expiration.

  When the MnesiaCache starts, it'll initialize invalidators for all stored
  keys using the `expire` value. If the `expire` datetime is past, it'll
  send call the invalidator immediately.

  ## Initialization options

    * `:nodes` - list of nodes to use. This value defaults to `[node()]`.

    * `:table_opts` - options to add to table definition. This value defaults
      to `[disc_copies: nodes]`.

    * `:timeout` - timeout value in milliseconds for how long to wait until the
      cache table has initiated. Defaults to 15 seconds.

  ## Configuration options

    * `:ttl` - integer value in milliseconds for ttl of records (required).

    * `:namespace` - string value to use for namespacing keys, defaults to
      "cache".
  """
  @behaviour Pow.Store.Base

  use GenServer
  alias Pow.Config

  @mnesia_cache_tab __MODULE__

  @spec start_link(Config.t()) :: GenServer.on_start()
  def start_link(config) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  @spec put(Config.t(), binary(), any()) :: :ok
  def put(config, key, value) do
    GenServer.cast(__MODULE__, {:cache, config, key, value})
  end

  @spec delete(Config.t(), binary()) :: :ok
  def delete(config, key) do
    GenServer.cast(__MODULE__, {:delete, config, key})
  end

  @spec get(Config.t(), binary()) :: any() | :not_found
  def get(config, key) do
    table_get(config, key)
  end

  @spec keys(Config.t()) :: [any()]
  def keys(config) do
    table_keys(config)
  end

  # Callbacks

  @spec init(Config.t()) :: {:ok, map()}
  def init(config) do
    table_init(config)

    {:ok, %{invalidators: init_invalidators(config)}}
  end

  @spec handle_cast({:cache, Config.t(), binary(), any()}, map()) :: {:noreply, map()}
  def handle_cast({:cache, config, key, value}, %{invalidators: invalidators} = state) do
    invalidators = update_invalidators(config, invalidators, key)
    table_update(config, key, value)

    {:noreply, %{state | invalidators: invalidators}}
  end

  @spec handle_cast({:delete, Config.t(), binary()}, map()) :: {:noreply, map()}
  def handle_cast({:delete, config, key}, %{invalidators: invalidators} = state) do
    invalidators = clear_invalidator(invalidators, key)
    table_delete(config, key)

    {:noreply, %{state | invalidators: invalidators}}
  end

  @spec handle_info({:invalidate, Config.t(), binary()}, map()) :: {:noreply, map()}
  def handle_info({:invalidate, config, key}, %{invalidators: invalidators} = state) do
    invalidators = clear_invalidator(invalidators, key)

    table_delete(config, key)

    {:noreply, %{state | invalidators: invalidators}}
  end

  defp update_invalidators(config, invalidators, key) do
    invalidators = clear_invalidator(invalidators, key)
    invalidator  = trigger_ttl(config, key, ttl(config))

    Map.put(invalidators, key, invalidator)
  end

  defp clear_invalidator(invalidators, key) do
    case Map.get(invalidators, key) do
      nil         -> nil
      invalidator -> Process.cancel_timer(invalidator)
    end

    Map.drop(invalidators, [key])
  end

  defp table_get(config, key) do
    mnesia_key = mnesia_key(config, key)

    {@mnesia_cache_tab, mnesia_key}
    |> :mnesia.dirty_read()
    |> case do
      [{@mnesia_cache_tab, ^mnesia_key, {_key, value, _config, _expire}} | _rest] ->
        value

      [] ->
        :not_found
    end
  end

  defp table_update(config, key, value) do
    mnesia_key = mnesia_key(config, key)
    value      = mnesia_value(config, key, value)

    :mnesia.transaction(fn ->
      :mnesia.write({@mnesia_cache_tab, mnesia_key, value})
    end)
  end

  defp table_delete(config, key) do
    mnesia_key = mnesia_key(config, key)

    :mnesia.transaction(fn ->
      :mnesia.delete({@mnesia_cache_tab, mnesia_key})
    end)
  end

  defp table_keys(config) do
    namespace = mnesia_key(config, "")

    @mnesia_cache_tab
    |> :mnesia.dirty_all_keys()
    |> Enum.filter(&String.starts_with?(&1, namespace))
  end

  defp table_init(config) do
    nodes      = Config.get(config, :nodes, [node()])
    table_opts = Config.get(config, :table_opts, disc_copies: nodes)
    table_def  = Keyword.merge(table_opts, [type: :set])
    timeout    = Config.get(config, :timeout, :timer.seconds(15))

    case :mnesia.create_schema(nodes) do
      :ok                                 -> :ok
      {:error, {_, {:already_exists, _}}} -> :ok
    end

    :rpc.multicall(nodes, :mnesia, :start, [])

    case :mnesia.create_table(@mnesia_cache_tab, table_def) do
      {:atomic, :ok}                                   -> :ok
      {:aborted, {:already_exists, @mnesia_cache_tab}} -> :ok
    end

    :ok = :mnesia.wait_for_tables([@mnesia_cache_tab], timeout)
  end

  defp mnesia_key(config, key) do
    namespace = Config.get(config, :namespace, "cache")

    "#{namespace}:#{key}"
  end

  defp mnesia_value(config, key, value) do
    {key, value, config, expire(ttl(config))}
  end

  defp init_invalidators(config) do
    config
    |> table_keys()
    |> Enum.map(&init_invalidator(config, &1))
    |> Enum.reject(&is_nil/1)
    |> Enum.into(%{})
  end

  defp init_invalidator(_config, key) do
    {@mnesia_cache_tab, key}
    |> :mnesia.dirty_read()
    |> case do
      [{@mnesia_cache_tab, ^key, {_key_id, _value, _config, nil}} | _rest] ->
        nil

      [{@mnesia_cache_tab, ^key, {key_id, _value, config, expire}} | _rest] ->
        ttl = Enum.max([expire - timestamp(), 0])

        {key, trigger_ttl(config, key_id, ttl)}

      [] -> nil
    end
  end

  defp trigger_ttl(config, key, ttl) do
    Process.send_after(self(), {:invalidate, config, key}, ttl)
  end

  defp expire(nil), do: nil
  defp expire(ttl), do: timestamp() + ttl

  defp timestamp, do: :os.system_time(:millisecond)

  defp ttl(config) do
    Config.get(config, :ttl) || raise_ttl_error()
  end

  @spec raise_ttl_error :: no_return
  defp raise_ttl_error,
    do: Config.raise_error("`:ttl` configuration option is required for #{__MODULE__}")
end
