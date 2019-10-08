defmodule Pow.Test.EtsCacheMock do
  @moduledoc false
  @tab __MODULE__

  def init, do: :ets.new(@tab, [:set, :protected, :named_table])

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

  def put(config, key, value) do
    send(self(), {:ets, :put, key, value, config})
    :ets.insert(@tab, {ets_key(config, key), value})
  end

  def keys(config) do
    namespace = ets_key(config, "")
    length    = String.length(namespace)

    Stream.resource(
      fn -> :ets.first(@tab) end,
      fn :"$end_of_table" -> {:halt, nil}
        previous_key -> {[previous_key], :ets.next(@tab, previous_key)} end,
      fn _ -> :ok
    end)
    |> Enum.filter(&String.starts_with?(&1, namespace))
    |> Enum.map(&String.slice(&1, length..-1))
  end

  defp ets_key(config, key) do
    namespace = Pow.Config.get(config, :namespace, "cache")

    "#{namespace}:#{key}"
  end
end
