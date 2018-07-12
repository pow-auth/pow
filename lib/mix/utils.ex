defmodule Mix.Authex.Utils do
  @moduledoc """
  Utilities module for mix tasks.
  """

  @spec no_umbrella!(binary()) :: :ok | no_return
  def no_umbrella!(task) do
    if Mix.Project.umbrella? do
      Mix.raise "mix #{task} can only be run inside an application directory"
    end

    :ok
  end

  @spec parse_options(OptionParser.argv(), Keyword.t(), Keyword.t()) :: map()
  def parse_options(args, switches, default_opts) do
    {opts, _parsed, _invalid} = OptionParser.parse(args, switches: switches)

    default_opts
    |> Keyword.merge(opts)
    |> Map.new()
    |> context_app_to_atom()
  end

  defp context_app_to_atom(%{context_app: context_app} = config),
    do: Map.put(config, :context_app, String.to_atom(context_app))
  defp context_app_to_atom(config),
    do: config
end
