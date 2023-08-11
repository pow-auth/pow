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
    view       = view(conn, web_module)
    layout     = layout(conn, web_module)

    conn
    |> Controller.put_view(view)
    |> Controller.put_layout(layout)
  end

  defp web_module(conn) do
    conn
    |> Plug.fetch_config()
    |> Config.get(:web_module)
  end

  defp view(conn, web_module) do
    conn
    |> Controller.view_module()
    |> build_view_module(web_module)
  end

  defp layout(conn, web_module) do
    conn
    |> Controller.layout()
    |> build_layout(web_module || web_base(conn))
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

    Module.concat([web_module, base, view])
  end

  # TODO: Remove `Pow.Phoenix.LayoutView` guard when Phoenix 1.7 is required
  defp build_layout({layout_view, template}, web_module) when layout_view in [Pow.Phoenix.Layouts, Pow.Phoenix.LayoutView] do
    layouts = Module.concat([web_module, Layouts])

    if Code.ensure_loaded?(layouts) do
      [html: {layouts, template}]
    else
      # TODO: Remove this when Phoenix 1.7 is required
      {Module.concat([web_module, LayoutView]), template}
    end
  end

  # Credo will complain about unless statement but we want this first
  # credo:disable-for-next-line
  unless Pow.dependency_vsn_match?(:phoenix, "< 1.7.0") do
  defp build_layout(layout, _web_module), do: [html: layout]
  else
  # TODO: Remove this when Phoenix 1.7 is required
  defp build_layout(layout, _web_module), do: layout
  end

  defp split_default_view(module) do
    module
    |> Atom.to_string()
    |> String.split(".Phoenix.")
  end
end
