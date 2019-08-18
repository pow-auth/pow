defmodule Pow.Phoenix.Router do
  @moduledoc """
  Handles Phoenix routing for Pow.

  Resources are build with `pow_resources/3` and individual routes are build
  with `pow_route/5`. The Pow routes will be filtered if a route has already
  been defined with the same action and router helper alias. This makes it easy
  to override pow routes with no conflicts.

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
      opts = unquote(__MODULE__).__filter_resource_actions__(@phoenix_routes, __ENV__.line, __ENV__.module, unquote(path), unquote(controller), unquote(opts))

      resources unquote(path), unquote(controller), opts
    end
  end

  @doc false
  def __filter_resource_actions__(phoenix_routes, line, module, path, controller, options) do
    resource     = Phoenix.Router.Resource.build(path, controller, options)
    action_verbs = [index: :get, new: :get, create: :post, show: :get, edit: :get, update: :patch]
    only         = Enum.reject(resource.actions, &__route_defined__(phoenix_routes, line, module, action_verbs[&1], path, controller, &1, options))

    Keyword.put(options, :only, only)
  end

  @doc false
  def __route_defined__(phoenix_routes, line, module, verb, path, plug, plug_opts, options) do
    line
    |> Phoenix.Router.Scope.route(module, :match, verb, path, plug, plug_opts, options)
    |> case do
      %{plug_opts: plug_opts, helper: helper} ->
        any_matching_routes?(phoenix_routes, %{plug_opts: plug_opts, helper: helper})

      # TODO: Remove this match by 1.1.0, and up requirement for Phoenix to minimum 1.4.7
      %{opts: plug_opts, helper: helper} ->
        any_matching_routes?(phoenix_routes, %{opts: plug_opts, helper: helper})

      _any ->
        false
    end
  end

  defp any_matching_routes?(phoenix_routes, needle) do
    keys = Map.keys(needle)

    Enum.any?(phoenix_routes, &Map.take(&1, keys) == needle)
  end

  defmacro pow_route(verb, path, plug, plug_opts, options \\ []) do
    quote location: :keep do
      unless unquote(__MODULE__).__route_defined__(@phoenix_routes, __ENV__.line, __ENV__.module, unquote(verb), unquote(path), unquote(plug), unquote(plug_opts), unquote(options)) do
        unquote(verb)(unquote(path), unquote(plug), unquote(plug_opts), unquote(options))
      end
    end
  end

  @spec validate_scope!(atom() | [%Phoenix.Router.Scope{}]) :: :ok | no_return
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
