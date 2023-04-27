defmodule Pow do
  @deps Enum.map(Mix.Dep.cached(), &{&1.app, &1.status})

  @moduledoc false

  @doc """
  Checks for version requirement in dependencies.

  The dependencies are loaded from the cache at compile-time.
  """
  @spec dependency_vsn_match?(atom(), binary()) :: boolean()
  def dependency_vsn_match?(dep, req) do
    @deps
    |> Keyword.get(dep, nil)
    |> case do
      {:ok, actual} -> Version.match?(actual, req)
      _error -> false
    end
  end
end
