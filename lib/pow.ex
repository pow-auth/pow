defmodule Pow do
  @moduledoc false

  @doc """
  Checks for version requirement in dependencies.

  The dependency will be loaded into the environment first.
  """
  @spec dependency_vsn_match?(atom(), binary()) :: boolean()
  def dependency_vsn_match?(dep, req) do
    Application.load(dep)

    case Application.spec(dep, :vsn) do
      nil -> false
      vsn -> Version.match?(List.to_string(vsn), req)
    end
  end
end
