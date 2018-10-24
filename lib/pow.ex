defmodule Pow do
  @moduledoc false

  @doc """
  Checks for version requirement in dependencies.
  """
  @spec dependency_vsn_match?(atom(), binary()) :: boolean()
  def dependency_vsn_match?(dep, req) do
    case :application.get_key(dep, :vsn) do
      {:ok, actual} ->
        actual
        |> List.to_string()
        |> Version.match?(req)

      _any ->
        false
    end
  end
end
