defmodule Pow.Store.Backend.EtsCache do
  @moduledoc """
  GenServer based key value ETS cache store with auto expiration.

  This module is not recommended for production, but mostly used as an example
  for how to build a cache. All data is stored in-memory, so cached values are
  not shared between machines.

  ## Configuration options

    * `:ttl` - integer value in milliseconds for ttl of records. If this value
      is not provided, or is set to nil, the records will never expire.

    * `:namespace` - value to use for namespacing keys. Defaults to "cache".

    * `:writes` - set to `:async` to do asynchronous writes. Defaults to
      `:sync`.
  """
  use GenServer
  alias Pow.{Config, Store.Backend.Base}

  @behaviour Base
  @ets_cache_tab __MODULE__

  @spec start_link(Base.config()) :: GenServer.on_start()
  def start_link(config) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  @impl Base
  def put(config, record_or_records) do
    case Config.get(config, :writes, :sync) do
      :sync ->
        GenServer.call(__MODULE__, {:cache, config, record_or_records})

      :async ->
        GenServer.cast(__MODULE__, {:cache, config, record_or_records})
    end
  end

  @impl Base
  def delete(config, key) do
    case Config.get(config, :writes, :sync) do
      :sync ->
        GenServer.call(__MODULE__, {:delete, config, key})

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
  def init(_config) do
    init_table()

    {:ok, %{invalidators: %{}}}
  end

  @impl GenServer
  def handle_call({:cache, config, record_or_records}, _from, state) do
    {:noreply, state} = handle_cast({:cache, config, record_or_records}, state)

    {:reply, :ok, state}
  end

  def handle_call({:delete, config, key}, _from, state) do
    {:noreply, state} = handle_cast({:delete, config, key}, state)

    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_cast({:cache, config, record_or_records}, %{invalidators: invalidators} = state) do
    invalidators =
      record_or_records
      |> table_insert(config)
      |> Enum.reduce(invalidators, &append_invalidator(elem(&1, 0), &2, config))

    {:noreply, %{state | invalidators: invalidators}}
  end

  def handle_cast({:delete, config, key}, %{invalidators: invalidators} = state) do
    invalidators =
      key
      |> table_delete(config)
      |> clear_invalidator(invalidators)

    {:noreply, %{state | invalidators: invalidators}}
  end

  @impl GenServer
  def handle_info({:invalidate, config, key}, %{invalidators: invalidators} = state) do
    invalidators =
      key
      |> table_delete(config)
      |> clear_invalidator(invalidators)

    {:noreply, %{state | invalidators: invalidators}}
  end

  defp table_get(key, config) do
    ets_key = ets_key(config, key)
    case :ets.lookup(@ets_cache_tab, ets_key) do
      [{^ets_key, value}] -> value
      []                  -> :not_found
    end
  end

  defp table_all(key_match, config) do
    ets_key_match = ets_key(config, key_match)

    @ets_cache_tab
    |> :ets.select([{{ets_key_match, :_}, [], [:"$_"]}])
    |> Enum.map(fn {key, value} -> {unwrap(key), value} end)
  end

  defp unwrap([_namespace, key]), do: key
  defp unwrap([_namespace | key]), do: key

  defp table_insert(record_or_records, config) do
    records     = List.wrap(record_or_records)
    ets_records = Enum.map(records, fn {key, value} ->
      {ets_key(config, key), value}
    end)

    :ets.insert(@ets_cache_tab, ets_records)

    records
  end

  defp table_delete(key, config) do
    ets_key = ets_key(config, key)

    :ets.delete(@ets_cache_tab, ets_key)

    key
  end

  defp init_table do
    :ets.new(@ets_cache_tab, [:ordered_set, :protected, :named_table])
  end

  defp ets_key(config, key) do
    [namespace(config) | List.wrap(key)]
  end

  defp namespace(config), do: Config.get(config, :namespace, "cache")

  defp append_invalidator(key, invalidators, config) do
    case Config.get(config, :ttl) do
      nil ->
        invalidators

      ttl ->
        invalidators = clear_invalidator(key, invalidators)
        invalidator  = trigger_ttl(key, ttl, config)

        Map.put(invalidators, key, invalidator)
    end
  end

  defp trigger_ttl(key, ttl, config) do
    Process.send_after(self(), {:invalidate, config, key}, ttl)
  end

  defp clear_invalidator(key, invalidators) do
    case Map.get(invalidators, key) do
      nil         -> nil
      invalidator -> Process.cancel_timer(invalidator)
    end

    Map.delete(invalidators, key)
  end

  # TODO: Remove by 1.1.0
  @deprecated "Use `put/2` instead"
  @doc false
  def put(config, key, value), do: put(config, {key, value})

  # TODO: Remove by 1.1.0
  @deprecated "Use `all/2` instead"
  @doc false
  def keys(config), do: all(config, :_)
end
