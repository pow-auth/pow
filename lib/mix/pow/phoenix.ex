defmodule Mix.Pow.Phoenix do
  @moduledoc """
  Utilities module for mix phoenix tasks.
  """
  alias Mix.Generator
  alias Mix.Pow

  @doc """
  Builds a map containing context and web module information.
  """
  @spec parse_structure(map()) :: map()
  def parse_structure(config) do
    otp_app      = Pow.otp_app()
    context_app  = Map.get(config, :context_app) || context_app(otp_app)
    context_base = Pow.app_base(context_app)
    web_base     = web_base(context_app, otp_app, context_base)
    web_prefix   = web_prefix(context_app, otp_app)

    %{
      context_app: context_app,
      context_base: context_base,
      web_app: otp_app,
      web_module: web_base,
      web_prefix: web_prefix
    }
  end

  defp context_app(otp_app) do
    otp_app
    |> Application.get_env(:generators, [])
    |> Keyword.get(:context_app)
    |> case do
      nil          -> otp_app
      false        -> Mix.raise("No context_app configured for current application")
      {app, _path} -> app
      app          -> app
    end
  end

  defp web_base(this_app, this_app, context_base), do: Module.concat(["#{context_base}Web"])
  defp web_base(_this_app, web_app, _context_base), do: Pow.app_base(web_app)

  defp web_prefix(this_app, this_app), do: Path.join("lib", "#{this_app}_web")
  defp web_prefix(_context_app, this_app), do: Path.join("lib", "#{this_app}")

  @doc """
  Creates a view file for the web module.
  """
  @spec create_view_file(atom(), binary(), atom(), binary()) :: :ok
  def create_view_file(module, name, web_mod, web_prefix) do
    path    = Path.join([web_prefix, "views", Macro.underscore(module), "#{name}_view.ex"])
    content = """
    defmodule #{inspect(web_mod)}.#{inspect(module)}.#{Macro.camelize(name)}View do
      use #{inspect(web_mod)}, :view
    end
    """

    Generator.create_file(path, content)

    :ok
  end

  @doc """
  Creates template files for the web module.
  """
  @spec create_templates(atom(), binary(), binary(), [binary()]) :: :ok
  def create_templates(module, name, web_prefix, actions) do
    template_module = Module.concat([module, Phoenix, "#{Macro.camelize(name)}Template"])
    path            = Path.join([web_prefix, "templates", Macro.underscore(module), name])

    actions
    |> Enum.map(&String.to_atom/1)
    |> Enum.each(fn action ->
      content   = template_module.html(action)
      file_path = Path.join(path, "#{action}.html.eex")

      Generator.create_file(file_path, content)
    end)
  end
end
