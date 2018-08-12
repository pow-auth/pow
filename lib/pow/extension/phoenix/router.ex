defmodule Pow.Extension.Phoenix.Router do
  @moduledoc """
  Handles extensions for the phonix router.

  ## Usage

  Configure `lib/my_project_web/router.ex` the following way:

      defmodule MyAppWeb.Router do
        use Phoenix.Router
        use Pow.Phoenix.Router
        use Pow.Extension.Phoenix.Router,
          extensions: [PowExtensionOne, PowExtensionTwo]

        pipeline :browser do
          plug :accepts, ["html"]
          plug :fetch_session
          plug :fetch_flash
          plug :protect_from_forgery
          plug :put_secure_browser_headers
        end

        scope "/" do
          pipe_through :browser

          pow_routes()
          pow_extension_routes()
        end
      end
  """
  alias Pow.{Config, Extension}

  defmacro __using__(config \\ []) do
    build_router_methods_module(__CALLER__.module, config)

    quote do
      @pow_extension_config unquote(config)

      import unquote(__MODULE__), only: [pow_extension_routes: 0]
    end
  end

  @doc """
  A macro that will call the router method in all extension router modules.
  """
  defmacro pow_extension_routes do
    router_methods = Module.concat(__CALLER__.module, RouterMethods).methods()

    for {router_module, router_method} <- router_methods do
      quote do
        require unquote(router_module)
        unquote(router_module).unquote(router_method)(@pow_extension_config)
      end
    end
  end

  @spec __router_extensions__(Config.t()) :: [atom()]
  def __router_extensions__(config) do
    Extension.Config.discover_modules(config, ["Phoenix", "Router"])
  end

  @spec __scope_namespace__(atom()) :: binary()
  def __scope_namespace__(module) do
    Extension.Config.underscore_extension(module)
  end

  @spec build_router_methods_module(module(), Config.t()) :: {:module, module(), binary(), term()}
  defp build_router_methods_module(module, config) do
    module = Module.concat(module, RouterMethods)

    Module.create(module, quote do
      def methods do
        for router_module <- unquote(__MODULE__).__router_extensions__(unquote(config)) do
          namespace      = unquote(__MODULE__).__scope_namespace__(router_module)
          router_method  = String.to_atom("#{namespace}_routes")

          {router_module, router_method}
        end
      end
    end, __ENV__)
  end
end
