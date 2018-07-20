defmodule Mix.Pow.Extension.Utils do
  @moduledoc """
  Utilities module for mix extension tasks.
  """

  @spec extensions(map()) :: [atom()]
  def extensions(config) do
    config
    |> Map.get(:extension, [])
    |> List.wrap()
    |> Enum.map(&Module.concat(Elixir, &1))
  end
end
