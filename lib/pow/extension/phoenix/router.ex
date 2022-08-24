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

  ## Customize Pow extension routes

  Pow extension routes can be overridden by defining them before the
  `pow_extension_routes/0` call. As an example, this can be used to change
  path:

      defmodule MyAppWeb.Router do
        use MyAppWeb, :router
        use Pow.Phoenix.Router
        use Pow.Extension.Phoenix.Router,
          extensions: [PowExtensionOne, PowExtensionTwo]

        # ...

        scope "/", PowExtensionOne.Phoenix, as: "pow_extension_one" do
          pipe_through [:browser]

          resources "/pow_extension_one", SomeController, only: [:new, :create]
        end

        scope "/" do
          pipe_through :browser

          pow_routes()
          pow_extension_routes()
        end

        # ...
      end
  """
  alias Pow.{Extension.Config, Phoenix.Router}

  @doc false
  defmacro __using__(config \\ []) do
    create_routers_module(__CALLER__.module, config)

    quote do
      @pow_extension_config unquote(config)

      import unquote(__MODULE__), only: [pow_extension_routes: 0]
    end
  end

  @doc """
  A macro that will call the routes function in all extension router modules.
  """
  defmacro pow_extension_routes do
    router_module(__CALLER__.module).routes()
  end

  defp create_routers_module(module, config) do
    router = router_module(module)

    Module.create(router, quote do
      @config unquote(config)
      @routers unquote(__MODULE__).__router_modules__(@config)

      def routes do
        for router <- @routers do
          quote do
            Router.validate_scope!(__MODULE__)

            require unquote(router)
            unquote(router).scoped_routes(@config)
          end
        end
      end
    end, __ENV__)
  end

  defp router_module(module) do
    Module.concat(module, PowExtensionRouter)
  end

  @doc false
  def __router_modules__(config) do
    config
    |> Config.extensions()
    |> Config.extension_modules(["Phoenix", "Router"])
  end
end
