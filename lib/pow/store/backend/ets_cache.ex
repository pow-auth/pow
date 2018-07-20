defmodule Pow.Store.Backend.EtsCache do
  @moduledoc """
  GenServer based key value ETS cache store with auto expiration.
  """
  @behaviour Pow.Store.Base

  use GenServer
  alias Pow.Config

  @ets_cache_tab __MODULE__

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
  def get(config, key), do: table_get(config, key)

  # Callbacks

  @spec init(Config.t()) :: {:ok, map()}
  def init(_config) do
    table_init()

    {:ok, %{invalidators: %{}}}
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
  def handle_info({:invalidate, config, key}, state) do
    table_delete(config, key)
    {:noreply, state}
  end

  defp update_invalidators(config, invalidators, key) do
    case Config.get(config, :ttl, nil) do
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
    key = ets_key(config, key)

    @ets_cache_tab
    |> :ets.lookup(key)
    |> case do
      [{^key, value} | _rest] -> value
      []                      -> :not_found
    end
  end

  defp table_update(config, key, value) do
    key = ets_key(config, key)
    :ets.insert(@ets_cache_tab, {key, value})
  end

  defp table_delete(config, key) do
    :ets.delete(@ets_cache_tab, ets_key(config, key))
  end

  defp table_init() do
    :ets.new(@ets_cache_tab, [:set, :protected, :named_table])
  end

  defp ets_key(config, key) do
    namespace = Config.get(config, :namespace, "cache")

    "#{namespace}:#{key}"
  end
end
