defmodule Pow.Phoenix.Router do
  @moduledoc """
  Handles Phoenix routing for Pow.

  Resources are build with `pow_resources/3` and individual routes are build
  with `pow_route/5`. The Pow routes will be filtered if a route has already
  been defined with the same action, router helper alias, and number of
  bindings. This makes it easy to override pow routes with no conflicts.

  The scope will be validated to ensure that there is no aliases. An exception
  will be raised if an alias was defined in any scope around the pow routes.

  ## Usage

  Configure `lib/my_project_web/router.ex` the following way:

      defmodule MyAppWeb.Router do
        use MyAppWeb, :router
        use Pow.Phoenix.Router

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
        end

        # ...
      end

  ## Disable registration routes

  `pow_routes/0` will call `pow_session_routes/0` and
  `pow_registration_routes/0`. Registration of new accounts can be disabled
  just by calling `pow_session_routes/0` instead of `pow_routes/0`:

      defmodule MyAppWeb.Router do
        use MyAppWeb, :router
        use Pow.Phoenix.Router

        # ...

        # Uncomment to permit update and deletion of user accounts:
        # scope "/", Pow.Phoenix, as: "pow" do
        #   pipe_through :browser
        #
        #   resources "/registration", RegistrationController, singleton: true, only: [:edit, :update, :delete]
        # end

        scope "/" do
          pipe_through :browser

          pow_session_routes()
        end

        # ...
      end

  ## Customize Pow routes

  Pow routes can be overridden by defining them before the `pow_routes/0` call.
  As an example, this can be used to change path:

      defmodule MyAppWeb.Router do
        use MyAppWeb, :router
        use Pow.Phoenix.Router

        # ...

        scope "/", Pow.Phoenix, as: "pow" do
          pipe_through :browser

          get "/sign_up", RegistrationController, :new
          post "/sign_up", RegistrationController, :create

          get "/login", SessionController, :new
          post "/login", SessionController, :create
        end

        scope "/" do
          pipe_through :browser

          pow_routes()
        end

        # ...
      end
  """

  @doc false
  defmacro __using__(_opts \\ []) do
    quote do
      import unquote(__MODULE__), only: [pow_routes: 0, pow_scope: 1, pow_session_routes: 0, pow_registration_routes: 0]
    end
  end

  @doc """
  Pow routes macro.

  Use this macro to define the Pow routes. This will call
  `pow_session_routes/0` and `pow_registration_routes/0`.

  ## Example

      scope "/" do
        pow_routes()
      end
  """
  defmacro pow_routes do
    quote do
      pow_session_routes()
      pow_registration_routes()
    end
  end

  @doc false
  defmacro pow_scope(do: context) do
    quote do
      unquote(__MODULE__).validate_scope!(__MODULE__)

      scope "/", Pow.Phoenix, as: "pow" do
        unquote(context)
      end
    end
  end

  @doc false
  defmacro pow_session_routes do
    quote location: :keep do
      pow_scope do
        unquote(__MODULE__).pow_resources "/session", SessionController, singleton: true, only: [:new, :create, :delete]
      end
    end
  end

  @doc false
  defmacro pow_registration_routes do
    quote location: :keep do
      pow_scope do
        unquote(__MODULE__).pow_resources "/registration", RegistrationController, singleton: true, only: [:new, :create, :edit, :update, :delete]
      end
    end
  end

  @doc false
  defmacro pow_resources(path, controller, opts) do
    quote location: :keep do
      phoenix_routes = Module.get_attribute(__ENV__.module, :phoenix_routes)
      phoenix_forwards = Module.get_attribute(__ENV__.module, :phoenix_forwards)
      opts = unquote(__MODULE__).__filter_resource_actions__({phoenix_routes, phoenix_forwards}, __ENV__.line, __ENV__.module, unquote(path), unquote(controller), unquote(opts))

      resources unquote(path), unquote(controller), opts
    end
  end

  @doc false
  def __filter_resource_actions__({phoenix_routes, phoenix_forwards}, line, module, path, controller, options) do
    resource    = Phoenix.Router.Resource.build(path, controller, options)
    param       = resource.param
    action_opts =
      if resource.singleton do
        [
          show:   {:get, path},
          new:    {:get, path <> "/new"},
          edit:   {:get, path <> "/edit"},
          create: {:post, path},
          delete: {:delete, path},
          update: {:patch, path}
        ]
      else
        [
          index:   {:get, path},
          show:    {:get, path <> "/:" <> param},
          new:     {:get, path <> "/new"},
          edit:    {:get, path <> "/:" <> param <> "/edit"},
          create:  {:post, path},
          delete:  {:delete, path <> "/:" <> param},
          update:  {:patch, path <> "/:" <> param}
        ]
      end

    only =
      Enum.reject(resource.actions, fn plug_opts ->
        {verb, path} = Keyword.fetch!(action_opts, plug_opts)

        __route_defined__({phoenix_routes, phoenix_forwards}, line, module, verb, path, controller, plug_opts, options)
      end)

    Keyword.put(options, :only, only)
  end

  @doc false
  def __route_defined__({phoenix_routes, phoenix_forwards}, line, module, verb, path, plug, plug_opts, options) do
    line
    |> Phoenix.Router.Scope.route(module, :match, verb, path, plug, plug_opts, options)
    |> case do
      %{plug_opts: _, helper: _} = route ->
        any_matching_routes?(phoenix_routes, phoenix_forwards, route, [:plug_opts, :helper])

      # TODO: Remove this match by 1.1.0, and up requirement for Phoenix to minimum 1.4.7
      %{opts: _, helper: _} = route ->
        any_matching_routes?(phoenix_routes, phoenix_forwards, route, [:opts, :helper])

      _any ->
        false
    end
  end

  defp any_matching_routes?(phoenix_routes, phoenix_forwards, route, keys) do
    needle       = Map.take(route, keys)
    route_exprs  = exprs(route, phoenix_forwards)

    Enum.any?(phoenix_routes, &Map.take(&1, keys) == needle && equal_binding_length?(&1, route_exprs, phoenix_forwards))
  end

  defp equal_binding_length?(route, exprs, forwards) do
    length(exprs.binding) == length(exprs(route, forwards).binding)
  end

  # TODO: Remove when Phoenix 1.7 is required
  if Code.ensure_loaded?(Phoenix.Router.Route) and function_exported?(Phoenix.Router.Route, :exprs, 1) do
    def exprs(route, _forwards), do: Phoenix.Router.Route.exprs(route)
  else
    defdelegate exprs(route, forwards), to: Phoenix.Router.Route
  end

  defmacro pow_route(verb, path, plug, plug_opts, options \\ []) do
    quote location: :keep do
      phoenix_routes = Module.get_attribute(__ENV__.module, :phoenix_routes)
      phoenix_forwards = Module.get_attribute(__ENV__.module, :phoenix_forwards)

      unless unquote(__MODULE__).__route_defined__({phoenix_routes, phoenix_forwards}, __ENV__.line, __ENV__.module, unquote(verb), unquote(path), unquote(plug), unquote(plug_opts), unquote(options)) do
        unquote(verb)(unquote(path), unquote(plug), unquote(plug_opts), unquote(options))
      end
    end
  end

  @spec validate_scope!(atom() | [Phoenix.Router.Scope.t()]) :: :ok
  def validate_scope!(module) when is_atom(module) do
    module
    |> Module.get_attribute(:phoenix_top_scopes)
    |> Kernel.||(Module.get_attribute(module, :phoenix_router_scopes))
    |> List.wrap()
    |> validate_scope!()
  end
  def validate_scope!([]), do: :ok # After Phoenix 1.4.4 this no longer happens since scope now always initializes with an empty Scopes map
  def validate_scope!(stack) when is_list(stack) do
    modules =
      stack
      |> Enum.map(& &1.alias)
      |> Enum.reject(fn
        nil -> true
        []  -> true
        _   -> false
      end)
      |> List.flatten()

    case modules do
      [] ->
        :ok

      modules ->
        raise ArgumentError,
          """
          Pow routes should not be defined inside scopes with aliases: #{inspect Module.concat(modules)}

          Please consider separating your scopes:

            scope "/" do
              pipe_through :browser

              pow_routes()
            end

            scope "/", #{inspect Module.concat(modules)} do
              pipe_through :browser

              get "/", PageController, :index
            end
          """
    end
  end

  defmodule Helpers do
    @moduledoc false

    alias Plug.Conn
    alias Pow.Phoenix.{RegistrationController, SessionController}

    @spec pow_session_path(Conn.t(), :new) :: binary()
    def pow_session_path(conn, :new) do
      SessionController.routes(conn).session_path(conn, :new)
    end

    @spec pow_registration_path(Conn.t(), :new) :: binary()
    def pow_registration_path(conn, :new) do
      RegistrationController.routes(conn).registration_path(conn, :new)
    end
  end
end
