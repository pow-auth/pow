defmodule Pow.Test.EtsCacheMock do
  @moduledoc false
  @tab __MODULE__

  def init, do: :ets.new(@tab, [:ordered_set, :protected, :named_table])

  def get(config, key) do
    ets_key = ets_key(config, key)

    @tab
    |> :ets.lookup(ets_key)
    |> case do
      [{^ets_key, value} | _rest] -> value
      []                          -> :not_found
    end
  end

  def delete(config, key) do
    :ets.delete(@tab, ets_key(config, key))

    :ok
  end

  def put(config, record_or_records) do
    records     = List.wrap(record_or_records)
    ets_records = Enum.map(records, fn {key, value} ->
      {ets_key(config, key), value}
    end)

    send(self(), {:ets, :put, records, config})
    :ets.insert(@tab, ets_records)
  end

  def all(config, match) do
    ets_key_match = ets_key(config, match)

    @tab
    |> :ets.select([{{ets_key_match, :_}, [], [:"$_"]}])
    |> Enum.map(fn {[_namespace | keys], value} -> {keys, value} end)
  end

  defp ets_key(config, key) do
    [Keyword.get(config, :namespace, "cache")] ++ List.wrap(key)
  end
end
