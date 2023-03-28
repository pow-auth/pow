defmodule Pow.Test.Phoenix.Web do
  @moduledoc false

  def router do
    quote do
      use Phoenix.Router, helpers: false

      # Import common connection and controller functions to use in pipelines
      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: Pow.Test.Phoenix.Endpoint,
        router: Pow.Test.Phoenix.Router,
        statics: ~w()
    end
  end

  def mail do
    quote do
      use Pow.Phoenix.Mailer.Component

      unquote(html_helpers())
    end
  end

  def html do
    quote do
      import Phoenix.Template, only: [embed_templates: 1, embed_templates: 2]

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      # Include general helpers for rendering HTML
      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      # HTML escaping functionality
      import Phoenix.HTML

      # Shortcut for generating JS commands
      alias Phoenix.LiveView.JS
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
