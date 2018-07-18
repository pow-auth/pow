defmodule Mix.Authex.Phoenix.Utils do
  @moduledoc """
  Utilities module for mix phoenix tasks.
  """
  alias Mix.Generator

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

  @spec create_view_file(atom(), binary(), atom(), binary()) :: :ok
  def create_view_file(module, name, web_mod, web_prefix) do
    path    = Path.join([web_prefix, "views", Macro.underscore(module), "#{name}_view.ex"])
    content = """
    defmodule #{inspect web_mod}.#{inspect module}.#{Macro.camelize(name)}View do
      use #{inspect web_mod}, :view
    end
    """

    Generator.create_file(path, content)
  end

  @spec create_templates(atom(), binary(), binary(), [binary()]) :: :ok
  def create_templates(module, name, web_prefix, actions) do
    path            = Path.join([web_prefix, "templates", Macro.underscore(module), name])
    template_module = Module.concat([module, Phoenix, "#{Macro.camelize(name)}Template"])

    actions
    |> Enum.map(&String.to_existing_atom/1)
    |> Enum.each(fn action ->
      content   = template_module.html(action)
      file_path = Path.join(path, "#{action}.html.eex")

      Generator.create_file(file_path, content)
    end)
  end
end
