defmodule Authex.Phoenix.ViewHelpers do
  @moduledoc """
  Module that renders views.

  The value set as :phoenix_views_namespace in the
  configuration option will be used. If not set,
  the default :phoenix_view inflection will be used.
  """
  alias Plug.Conn
  alias Authex.{Authorization.Plug, Config}

  @spec render(Conn.t(), binary() | atom(), Keyword.t() | map() | binary() | atom()) :: Conn.t()
  def render(conn, template, assigns \\ []) do
    default_view = Map.get(conn.private, :phoenix_view)
    {default_layout_view, layout_template} =
      Map.get(conn.private, :phoenix_layout)
    namespace =
      conn
      |> Plug.fetch_config()
      |> Config.get(:phoenix_views_namespace, nil)

    view        = maybe_build_module_name(namespace, default_view)
    layout_view = maybe_build_module_name(namespace, default_layout_view)

    conn
    |> Phoenix.Controller.put_view(view)
    |> Phoenix.Controller.put_layout({layout_view, layout_template})
    |> Phoenix.Controller.render(template, assigns)
  end

  defp maybe_build_module_name(nil, view), do: view
  defp maybe_build_module_name(namespace, view), do: module_name(namespace, view)

  defp module_name(namespace, view) do
    [_authex, _phoenix, rest] = Module.split(view)
    rest                      = List.wrap(rest)
    namespace                 = Module.split(namespace)

    namespace
    |> Enum.concat(rest)
    |> Module.concat()
  end
end
