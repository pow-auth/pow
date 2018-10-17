defmodule Pow.Test.EtsCacheMock do
  @moduledoc false
  @tab __MODULE__

  def init, do: :ets.new(@tab, [:set, :protected, :named_table])

  def get(_config, key) do
    @tab
    |> :ets.lookup(key)
    |> case do
      [{^key, value} | _rest] -> value
      []                      -> :not_found
    end
  end

  def delete(_config, key) do
    :ets.delete(@tab, key)
  end

  def put(_config, key, value) do
    :ets.insert(@tab, {key, value})
  end

  def keys(_config) do
    Stream.resource(
      fn -> :ets.first(@tab) end,
      fn :"$end_of_table" -> {:halt, nil}
        previous_key -> {[previous_key], :ets.next(@tab, previous_key)} end,
      fn _ -> :ok
    end)
  end
end
