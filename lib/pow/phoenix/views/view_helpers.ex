defmodule Pow.Phoenix.ViewHelpers do
  @moduledoc """
  Module that renders views.

  By default, the controller views and templates in this library will be used,
  and the layout view will be based on the module namespace of the Endpoint
  module.

  By setting the `:web_module` key in config, the controller and layout views
  can be used from this context app.

  So if you set up your endpoint like this:

      defmodule MyAppWeb.Endpoint do
        plug Pow.Plug.Session
      end

  Only `MyAppWeb.LayoutView` will be used from your app. However, if you set up
  the endpoint with a `:web_module` key:

      defmodule MyAppWeb.Endpoint do
        plug Pow.Plug.Session, web_module: MyAppWeb
      end

  The following modules are will be used from your app:

    * `MyAppWeb.LayoutView`
    * `MyAppWeb.Pow.RegistrationView`
    * `MyAppWeb.Pow.SessionView`

  And also the following templates has to exist in
  `lib/my_project_web/templates/pow`:

    * `registration/new.html.eex`
    * `registration/edit.html.eex`
    * `session/new.html.eex`
  """
  alias Phoenix.Controller
  alias Plug.Conn
  alias Pow.{Config, Plug}

  @doc """
  Updates the view and layout view in the connection.

  The layout view is always updated. If `:web_module` is not provided, it'll be
  computed from the Endpoint module, and the default Pow view module is
  returned.

  When `:web_module` is provided, both the view module and the layout view
  module will be computed. See `build_view_module/2` for more.
  """
  @spec layout(Conn.t()) :: Conn.t()
  def layout(conn) do
    web_module =
      conn
      |> Plug.fetch_config()
      |> Config.get(:web_module)

    view       = view(conn, web_module)
    layout     = layout(conn, web_module)

    conn
    |> Controller.put_view(view)
    |> Controller.put_layout(layout)
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
    conn
    |> Controller.endpoint_module()
    |> split_module()
    |> Enum.reverse()
    |> Enum.slice(1..-1)
    |> Enum.reverse()
  end

  @doc """
  Generates the view module atom.

  If no `web_module` is provided, the Pow view module is returned.

  When `web_module` is provided, the view module will be changed from e.g.
  `Pow.Phoenix.RegistrationView` to `CustomWeb.Pow.RegistrationView`
  """
  @spec build_view_module(module(), module() | nil) :: module()
  def build_view_module(pow_view, nil), do: pow_view
  def build_view_module(pow_view, web_module) when is_atom(web_module) do
    web_module_pow = web_module_pow(pow_view, web_module)

    prepend_web_module(pow_view, web_module_pow)
  end

  defp web_module_pow(pow_view, web_module) do
    [pow_base_module | _rest] = split_module(pow_view)

    split_module(web_module) ++ [pow_base_module]
  end

  defp build_layout({pow_view, template}, web_module) when is_atom(web_module) do
    build_layout({pow_view, template}, split_module(web_module))
  end
  defp build_layout({pow_view, template}, web_module) do
    view = prepend_web_module(pow_view, web_module)

    {view, template}
  end

  defp prepend_web_module(pow_view, base) when is_atom(pow_view) do
    pow_view
    |> split_module()
    |> prepend_web_module(base)
  end
  defp prepend_web_module([_pow_base, "Phoenix" | rest], base) do
    base
    |> Enum.concat(rest)
    |> Module.concat()
  end

  defp split_module(module) when is_atom(module), do: Module.split(module)
end
