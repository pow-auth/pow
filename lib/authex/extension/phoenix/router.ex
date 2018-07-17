defmodule Authex.Extension.Phoenix.Router do
  @moduledoc """
  Handles extensions for the phonix router.

  ## Usage

  Configure `lib/my_project_web/router.ex` the following way:

      defmodule MyAppWeb.Router do
        use Phoenix.Router
        use Authex.Phoenix.Router
        use Authex.Extension.Phoenix.Router,
          extensions: [AuthexExtensionOne, AuthexExtensionTwo]

        pipeline :browser do
          plug :accepts, ["html"]
          plug :fetch_session
          plug :fetch_flash
          plug :protect_from_forgery
          plug :put_secure_browser_headers
        end

        scope "/" do
          pipe_through :browser

          authex_routes()
          authex_extension_routes()
        end
      end
  """
  alias Authex.Extension

  defmacro __using__(config \\ []) do
    build_config_module(__CALLER__.module, config)

    quote do
      import unquote(__MODULE__), only: [authex_extension_routes: 0]
    end
  end

  defmacro authex_extension_routes() do
    config = Module.concat(__CALLER__.module, RoutesConfig).config()

    for router_module <- __MODULE__.__router_extensions__(config) do
      phoenix_module = __MODULE__.__phoenix_module__(router_module)
      namespace      = __MODULE__.__scope_namespace__(phoenix_module)

      quote do
        scope "/", unquote(phoenix_module), as: unquote(namespace) do
          unquote(router_module.routes(config))
        end
      end
    end
  end

  def build_config_module(module, config) do
    module = Module.concat(module, RoutesConfig)

    Module.create(module, quote do
      def config, do: unquote(config)
    end, __ENV__)
  end

  @spec __router_extensions__(Config.t()) :: [atom()]
  def __router_extensions__(config) do
    config
    |> Extension.Config.extensions()
    |> Enum.map(&Module.concat([&1, "Phoenix", "Router"]))
    |> Enum.filter(&Code.ensure_compiled?/1)
    |> Enum.reject(&is_nil/1)
  end

  @spec __phoenix_module__(atom()) :: atom()
  def __phoenix_module__(module) do
    module
    |> Module.split()
    |> Enum.drop(-1)
    |> Module.concat()
  end

  @spec __scope_namespace__(atom()) :: binary()
  def __scope_namespace__(module) do
    module
    |> Module.split()
    |> List.first()
    |> Macro.underscore()
  end
end
