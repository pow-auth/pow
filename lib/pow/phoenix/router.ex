defmodule Pow.Phoenix.Router do
  @moduledoc """
  Handles Phoenix routing for Pow.

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
  Pow router macro.

  Use this macro to define the Pow routes.

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
        resources "/session", SessionController, singleton: true, only: [:new, :create, :delete]
      end
    end
  end

  @doc false
  defmacro pow_registration_routes do
    quote location: :keep do
      pow_scope do
        resources "/registration", RegistrationController, singleton: true, only: [:new, :create, :edit, :update, :delete]
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
