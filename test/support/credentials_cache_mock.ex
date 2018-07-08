defmodule Authex.Test.CredentialsCacheMock do
  @tab __MODULE__

  def init(), do: :ets.new(@tab, [:set, :protected, :named_table])

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

  def create(_config, key, value) do
    :ets.insert(@tab, {key, value})
  end
end
