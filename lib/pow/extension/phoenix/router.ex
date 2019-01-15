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
  alias Pow.{Extension.Config, Phoenix.Router}

  defmacro __using__(config \\ []) do
    __create_routers_module__(__CALLER__.module, config)

    quote do
      @pow_extension_config unquote(config)

      import unquote(__MODULE__), only: [pow_extension_routes: 0]
    end
  end

  @doc """
  A macro that will call the router method in all extension router modules.
  """
  defmacro pow_extension_routes do
    __router_module__(__CALLER__.module).routes()
  end

  defp __create_routers_module__(module, config) do
    router = __router_module__(module)

    Module.create(router, quote do
      @config unquote(config)
      @routers Config.discover_modules(@config, ["Phoenix", "Router"])

      def routes do
        for router <- @routers do
          quote do
            Router.validate_scope!(@phoenix_router_scopes)

            require unquote(router)
            unquote(router).scoped_routes(@config)
          end
        end
      end
    end, __ENV__)
  end

  defp __router_module__(module) do
    Module.concat(module, PowExtensionRouter)
  end
end
