defmodule Pow.Phoenix.ViewHelpers do
  @moduledoc """
  Module that renders templates.

  By default, the controller templates in this library will be used, and the
  layout templates will be based on the module namespace of the Endpoint
  module.

  By setting the `:web_module` key in config, the controller and layout
  templates can be used from this context app.

  So if you set up your endpoint like this:

      defmodule MyAppWeb.Endpoint do
        plug Pow.Plug.Session
      end

  Only `MyAppWeb.Layouts` will be used from your app. However, if you set up
  the endpoint with a `:web_module` key:

      defmodule MyAppWeb.Endpoint do
        plug Pow.Plug.Session, web_module: MyAppWeb
      end

  The following modules will be used from your app:

    * `MyAppWeb.Layouts`
    * `MyAppWeb.Pow.RegistrationHTML`
    * `MyAppWeb.Pow.SessionHTML`

  And also the following templates has to exist in
  `lib/my_project_web/controllers/pow`:

    * `registration_html/new.html.heex`
    * `registration_html/edit.html.heex`
    * `session_html/new.html.heex`
  """
  alias Phoenix.Controller
  alias Plug.Conn
  alias Pow.{Config, Plug}

  @doc """
  Updates the layout module in the connection.

  The layout template is always updated. If `:web_module` is not provided,
  it'll be computed from the Endpoint module, and the default Pow template
  module is returned.

  When `:web_module` is provided, both the template module and the layout
  template module will be computed. See `build_view_module/2` for more.
  """
  @spec layout(Conn.t()) :: Conn.t()
  def layout(conn) do
    web_module = web_module(conn)
    view       = html_view(conn, web_module)
    layout     = html_layout(conn, web_module)

    conn
    |> Controller.put_view(view)
    |> Controller.put_layout(layout)
  end

  defp web_module(conn) do
    conn
    |> Plug.fetch_config()
    |> Config.get(:web_module)
  end

  # Credo will complain about unless statement but we want this first
  # credo:disable-for-next-line
  unless Pow.dependency_vsn_match?(:phoenix, "< 1.7.0") do
  defp html_view(conn, web_module) do
    [html: conn
           |> Controller.view_module("html")
           |> build_view_module(web_module)]
  end
  else
  # TODO: Remove this when Phoenix 1.7 is required
  defp html_view(conn, web_module) do
    conn
    |> Controller.view_module()
    |> build_view_module(web_module)
  end
  end


  # Credo will complain about unless statement but we want this first
  # credo:disable-for-next-line
  unless Pow.dependency_vsn_match?(:phoenix, "< 1.7.0") do
  defp html_layout(conn, web_module) do
    [html: conn
           |> Controller.layout("html")
           |> build_layout(web_module || web_base(conn))]
  end
  else
  # TODO: Remove this when Phoenix 1.7 is required
  defp html_layout(conn, web_module) do
    conn
    |> Controller.layout()
    |> build_layout(web_module || web_base(conn))
  end
  end

  defp web_base(conn) do
    ["Endpoint" | web_context] =
      conn
      |> Controller.endpoint_module()
      |> Module.split()
      |> Enum.reverse()

    web_context
    |> Enum.reverse()
    |> Module.concat()
  end

  @doc """
  Generates the template module atom.

  If no `web_module` is provided, the Pow template module is returned.

  When `web_module` is provided, the template module will be changed from
  `Pow.Phoenix.RegistrationHTML` to `CustomWeb.Pow.RegistrationHTML`
  """
  @spec build_view_module(module(), module() | nil) :: module()
  def build_view_module(default_view, nil), do: default_view
  def build_view_module(default_view, web_module) when is_atom(web_module) do
    [base, view] = split_default_view(default_view)
    module = Module.concat([web_module, base, view])

    case Code.ensure_loaded?(Phoenix.View) and not Code.ensure_loaded?(module) do
      # TODO: Remove when Phoenix 1.7 is required
      true ->
        module
        |> to_string()
        |> Phoenix.Naming.unsuffix("HTML")
        |> Kernel.<>("View")
        |> String.to_atom()

      false ->
        module
    end
  end

  # Credo will complain about unless statement but we want this first
  # credo:disable-for-next-line
  unless Pow.dependency_vsn_match?(:phoenix, "< 1.7.0") do
  defp build_layout({layout_view, template}, web_module) when layout_view in [Pow.Phoenix.Layouts, Pow.Phoenix.LayoutView] do
    layouts = Module.concat([web_module, Layouts])

    if Code.ensure_loaded?(layouts) do
      {layouts, template}
    else
      # TODO: Remove this when Phoenix 1.7 is required and Layouts module is required
      {Module.concat([web_module, LayoutView]), template}
    end
  end

  defp build_layout(layout, _web_module), do: layout
  else
  # TODO: Remove this when Phoenix 1.7 is required
  defp build_layout({Pow.Phoenix.LayoutView, template}, web_module) do
    {Module.concat([web_module, LayoutView]), template}
  end

  defp build_layout(layout, _web_module), do: layout
  end

  defp split_default_view(module) do
    module
    |> Atom.to_string()
    |> String.split(".Phoenix.")
  end
end
