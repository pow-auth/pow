defmodule Mix.Phoenix.Utils do
  @spec parse_structure(map()) :: map()
  def parse_structure(config) do
    context_app  = Map.get(config, :context_app, Mix.Authex.Utils.context_app())
    context_base = Mix.Authex.Utils.context_base(context_app)
    web_prefix   = web_path(context_app)
    web_module   = web_module(context_base, web_prefix)

    %{
      context_app: context_app,
      context_base: context_base,
      web_prefix: web_prefix,
      web_module: web_module
    }
  end

  defp web_path(this_app), do: Path.join("lib", "#{this_app}_web")

  defp web_module(base, web_prefix) do
    case String.ends_with?(web_prefix, "_web") do
      true  -> Module.concat(["#{base}Web"])
      false -> Module.concat([base])
    end
  end
end
