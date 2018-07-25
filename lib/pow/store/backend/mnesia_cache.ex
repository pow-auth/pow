defmodule Pow.Store.Backend.MnesiaCache do
  @moduledoc """
  GenServer based key value Mnesia cache store with auto expiration.

  ## Initialization options

    * `:nodes` list of nodes to use, defaults to [node()]

  ## Configuration options

    * `:ttl` integer value for ttl of records
    * `:namespace` string value to use for namespacing keys
  """
  @behaviour Pow.Store.Base

  alias Pow.Config

  @mnesia_cache_tab __MODULE__

  @spec start_link(Config.t()) :: GenServer.on_start()
  def start_link(config) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  @spec put(Config.t(), binary(), any()) :: :ok
  def put(config, key, value) do
    key   = mnesia_key(config, key)
    value = mnesia_value(config, value)

    GenServer.cast(__MODULE__, {:cache, config, key, value})
  end

  @spec delete(Config.t(), binary()) :: :ok
  def delete(config, key) do
    key = mnesia_key(config, key)

    GenServer.cast(__MODULE__, {:delete, config, key})
  end

  @spec get(Config.t(), binary()) :: any() | :not_found
  def get(config, key) do
    key = mnesia_key(config, key)

    table_get(key)
  end

  @spec init(Config.t()) :: {:ok, map()}
  def init(config) do
    table_init(config)
    invalidators = init_invalidators(config)

    {:ok, %{invalidators: invalidators}}
  end

  @spec handle_cast({:cache, Config.t(), binary(), any()}, map()) :: {:noreply, map()}
  def handle_cast({:cache, config, key, value}, %{invalidators: invalidators} = state) do
    invalidators = update_invalidators(config, invalidators, key)
    table_update(key, value)

    {:noreply, %{state | invalidators: invalidators}}
  end

  @spec handle_cast({:delete, Config.t(), binary()}, map()) :: {:noreply, map()}
  def handle_cast({:delete, _config, key}, %{invalidators: invalidators} = state) do
    invalidators = clear_invalidator(invalidators, key)
    table_delete(key)

    {:noreply, %{state | invalidators: invalidators}}
  end

  @spec handle_info({:invalidate, Config.t(), binary()}, map()) :: {:noreply, map()}
  def handle_info({:invalidate, _config, key}, %{invalidators: invalidators} = state) do
    invalidators = clear_invalidator(invalidators, key)
    table_delete(key)

    {:noreply, %{state | invalidators: invalidators}}
  end

  defp update_invalidators(config, invalidators, key) do
    invalidators = clear_invalidator(invalidators, key)
    invalidator = trigger_ttl(config, key, ttl(config))

    Map.put(invalidators, key, invalidator)
  end

  defp clear_invalidator(invalidators, key) do
    case Map.get(invalidators, key) do
      nil         -> nil
      invalidator -> Process.cancel_timer(invalidator)
    end

    Map.drop(invalidators, [key])
  end

  defp table_get(key) do
    {@mnesia_cache_tab, key}
    |> :mnesia.dirty_read()
    |> case do
      [{@mnesia_cache_tab, ^key, {value, _expire}} | _rest] ->
        value

      [] ->
        :not_found
    end
  end

  defp table_update(key, value) do
    :mnesia.transaction(fn ->
      :mnesia.write({@mnesia_cache_tab, key, value})
    end)
  end

  defp table_delete(key) do
    :mnesia.transaction(fn ->
      :mnesia.delete({@mnesia_cache_tab, key})
    end)
  end

  defp table_init(config) do
    nodes = Config.get(config, :nodes, [node()])

    case :mnesia.create_schema(nodes) do
      :ok -> :ok
      {:error, {_, {:already_exists, _}}} -> :ok
    end

    :rpc.multicall(nodes, :mnesia, :start, [])

    case :mnesia.create_table(@mnesia_cache_tab, [type: :set, disc_copies: nodes]) do
      {:atomic, :ok} -> :ok
      {:aborted, {:already_exists, @mnesia_cache_tab}} -> :ok
    end

    :ok = :mnesia.wait_for_tables([@mnesia_cache_tab], :timer.seconds(15))
  end

  defp mnesia_key(config, key) do
    namespace = Config.get(config, :namespace, "cache")

    "#{namespace}:#{key}"
  end

  defp mnesia_value(config, value) do
    {value, expire(ttl(config))}
  end

  defp init_invalidators(config) do
    @mnesia_cache_tab
    |> :mnesia.dirty_all_keys()
    |> Enum.map(&init_invalidator(config, &1))
    |> Enum.reject(&is_nil/1)
    |> Enum.into(%{})
  end

  defp init_invalidator(config, key) do
    {@mnesia_cache_tab, key}
    |> :mnesia.dirty_read()
    |> case do
      [{@mnesia_cache_tab, ^key, {_value, nil}} | _rest] ->
        nil

      [{@mnesia_cache_tab, ^key, {_value, expire}} | _rest] ->
        ttl = Enum.max([expire - timestamp(), 0])
        {key, trigger_ttl(config, key, ttl)}

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
    Config.get(config, :ttl, nil) || raise_ttl_error()
  end

  @spec raise_ttl_error :: no_return
  defp raise_ttl_error, do: Config.raise_error("`:ttl` configuration option is required for #{__MODULE__}")
end
