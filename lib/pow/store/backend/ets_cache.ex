defmodule Pow.Store.Backend.EtsCache do
  @moduledoc """
  GenServer based key value ETS cache store with auto expiration.

  This module is not recommended for production, but mostly used as an example
  for how to build a cache. All data is stored in-memory, so cached values are
  not shared between machines.

  ## Configuration options

    * `:ttl` - integer value in milliseconds for ttl of records. If this value
      is not provided, or is set to nil, the records will never expire.

    * `:namespace` - string value to use for namespacing keys. Defaults to
      "cache".
  """
  use GenServer
  alias Pow.{Config, Store.Base}

  @behaviour Base
  @ets_cache_tab __MODULE__

  @spec start_link(Config.t()) :: GenServer.on_start()
  def start_link(config) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  @impl Base
  @spec put(Config.t(), binary(), any()) :: :ok
  def put(config, key, value) do
    GenServer.cast(__MODULE__, {:cache, config, key, value})
  end

  @impl Base
  @spec delete(Config.t(), binary()) :: :ok
  def delete(config, key) do
    GenServer.cast(__MODULE__, {:delete, config, key})
  end

  @impl Base
  @spec get(Config.t(), binary()) :: any() | :not_found
  def get(config, key) do
    table_get(config, key)
  end

  @impl Base
  @spec keys(Config.t()) :: [any()]
  def keys(config) do
    table_keys(config)
  end

  # Callbacks

  @impl GenServer
  @spec init(Config.t()) :: {:ok, map()}
  def init(_config) do
    init_table()

    {:ok, %{invalidators: %{}}}
  end

  @impl GenServer
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

  @impl GenServer
  @spec handle_info({:invalidate, Config.t(), binary()}, map()) :: {:noreply, map()}
  def handle_info({:invalidate, config, key}, %{invalidators: invalidators} = state) do
    invalidators = clear_invalidator(invalidators, key)

    table_delete(config, key)

    {:noreply, %{state | invalidators: invalidators}}
  end

  defp update_invalidators(config, invalidators, key) do
    case Config.get(config, :ttl) do
      nil ->
        invalidators

      ttl ->
        invalidators = clear_invalidator(invalidators, key)
        invalidator = Process.send_after(self(), {:invalidate, config, key}, ttl)

        Map.put(invalidators, key, invalidator)
    end
  end

  defp clear_invalidator(invalidators, key) do
    case Map.get(invalidators, key) do
      nil         -> nil
      invalidator -> Process.cancel_timer(invalidator)
    end

    Map.drop(invalidators, [key])
  end

  defp table_get(config, key) do
    ets_key = ets_key(config, key)

    @ets_cache_tab
    |> :ets.lookup(ets_key)
    |> case do
      [{^ets_key, value} | _rest] -> value
      []                      -> :not_found
    end
  end

  defp table_update(config, key, value),
    do: :ets.insert(@ets_cache_tab, {ets_key(config, key), value})

  defp table_delete(config, key), do: :ets.delete(@ets_cache_tab, ets_key(config, key))

  defp init_table do
    :ets.new(@ets_cache_tab, [:set, :protected, :named_table])
  end

  defp table_keys(config) do
    namespace = ets_key(config, "")
    length    = String.length(namespace)

    Stream.resource(
      fn -> :ets.first(@ets_cache_tab) end,
      fn :"$end_of_table" -> {:halt, nil}
        previous_key -> {[previous_key], :ets.next(@ets_cache_tab, previous_key)} end,
      fn _ -> :ok
    end)
    |> Enum.filter(&String.starts_with?(&1, namespace))
    |> Enum.map(&String.slice(&1, length..-1))
  end

  defp ets_key(config, key) do
    namespace = Config.get(config, :namespace, "cache")

    "#{namespace}:#{key}"
  end
end
