defmodule Pow.Phoenix.Routes do
  @moduledoc """
  Module that handles routes.

  ## Usage

      defmodule MyAppWeb.Pow.Routes do
        use Pow.Phoenix.Routes
        alias MyAppWeb.Router.Helpers, as: Routes

        @impl true
        def after_sign_out_path(conn), do: Routes.some_path(conn, :index)
      end

  Update configuration with `routes_backend: MyAppWeb.Pow.Routes`.

  You can also customize path generation:

      defmodule MyAppWeb.Pow.Routes do
        use Pow.Phoenix.Routes
        alias MyAppWeb.Router.Helpers, as: Routes

        @impl true
        def url_for(conn, verb, vars \\ [], query_params \\ [])
        def url_for(conn, PowEmailConfirmation.Phoenix.ConfirmationController, :show, [token], _query_params),
          do: Routes.custom_confirmation_url(conn, :new, token)
        def url_for(conn, plug, verb, vars, query_params),
          do: Pow.Phoenix.Routes.url_for(conn, plug, verb, vars, query_params)
      end
  """
  alias Plug.Conn
  alias Pow.Phoenix.{Controller, RegistrationController, SessionController}

  @callback user_not_authenticated_path(Conn.t()) :: binary()
  @callback user_already_authenticated_path(Conn.t()) :: binary()
  @callback after_sign_out_path(Conn.t()) :: binary()
  @callback after_sign_in_path(Conn.t()) :: binary()
  @callback after_registration_path(Conn.t()) :: binary()
  @callback after_user_updated_path(Conn.t()) :: binary()
  @callback after_user_deleted_path(Conn.t()) :: binary()
  @callback session_path(Conn.t(), atom(), list()) :: binary()
  @callback registration_path(Conn.t(), atom()) :: binary()
  @callback path_for(Conn.t(), atom(), atom(), list(), Keyword.t()) :: binary()
  @callback url_for(Conn.t(), atom(), atom(), list(), Keyword.t()) :: binary()

  @doc false
  defmacro __using__(_opts) do
    quote do
      @behaviour unquote(__MODULE__)

      def user_not_authenticated_path(conn),
        do: unquote(__MODULE__).user_not_authenticated_path(conn, __MODULE__)

      def user_already_authenticated_path(conn),
        do: unquote(__MODULE__).user_already_authenticated_path(conn, __MODULE__)

      def after_sign_out_path(conn),
        do: unquote(__MODULE__).after_sign_out_path(conn, __MODULE__)

      def after_sign_in_path(conn),
        do: unquote(__MODULE__).after_sign_in_path(conn, __MODULE__)

      def after_registration_path(conn),
        do: unquote(__MODULE__).after_registration_path(conn, __MODULE__)

      def after_user_updated_path(conn),
        do: unquote(__MODULE__).after_user_updated_path(conn, __MODULE__)

      def after_user_deleted_path(conn),
        do: unquote(__MODULE__).after_user_deleted_path(conn, __MODULE__)

      def session_path(conn, verb, query_params \\ []),
        do: unquote(__MODULE__).session_path(conn, verb, query_params, __MODULE__)

      def registration_path(conn, verb),
        do: unquote(__MODULE__).registration_path(conn, verb, __MODULE__)

      def path_for(conn, plug, verb, vars \\ [], query_params \\ []),
        do: unquote(__MODULE__).path_for(conn, plug, verb, vars, query_params)

      def url_for(conn, plug, verb, vars \\ [], query_params \\ []),
        do: unquote(__MODULE__).url_for(conn, plug, verb, vars, query_params)

      defoverridable unquote(__MODULE__)
    end
  end

  @doc """
  Path to redirect user to when user is not authenticated.

  This will put a `:request_path` param into the path that can be used to
  redirect users back the the page they first attempted to visit. See
  `after_sign_in_path/1` for how `:request_path` is handled.

  The `:request_path` will only be added if the request uses "GET" method.

  See `Pow.Phoenix.SessionController` for more on how this value is handled.
  """
  def user_not_authenticated_path(conn, routes_module \\ __MODULE__) do
    case conn.method do
      "GET"   -> routes_module.session_path(conn, :new, request_path: Phoenix.Controller.current_path(conn))
      _method -> routes_module.session_path(conn, :new)
    end
  end

  @doc """
  Path to redirect user to when user has already been authenticated.

  By default this is the same as `after_sign_in_path/1`.
  """
  def user_already_authenticated_path(conn, routes_module \\ __MODULE__), do: routes_module.after_sign_in_path(conn)

  @doc """
  Path to redirect user to when user has signed out.
  """
  def after_sign_out_path(conn, routes_module \\ __MODULE__), do: routes_module.session_path(conn, :new)

  @doc """
  Path to redirect user to when user has signed in.

  This will look for a `:request_path` assigns key, and redirect to this value
  if it exists.
  """
  def after_sign_in_path(params, routes_module \\ __MODULE__)
  def after_sign_in_path(%{assigns: %{request_path: request_path}}, _routes_module) when is_binary(request_path),
    do: request_path

  def after_sign_in_path(_params, _routes_module), do: "/"

  @doc """
  Path to redirect user to when user has signed up.

  By default this is the same as `after_sign_in_path/1`.
  """
  def after_registration_path(conn, routes_module \\ __MODULE__), do: routes_module.after_sign_in_path(conn)

  @doc """
  Path to redirect user to when user has updated their account.
  """
  def after_user_updated_path(conn, routes_module \\ __MODULE__), do: routes_module.registration_path(conn, :edit)

  @doc """
  Path to redirect user to when user has deleted their account.

  By default this is the same as `after_sign_out_path/1`.
  """
  def after_user_deleted_path(conn, routes_module \\ __MODULE__), do: routes_module.after_sign_out_path(conn)

  @doc false
  def session_path(conn, verb, query_params \\ [], routes_module \\ __MODULE__), do: routes_module.path_for(conn, SessionController, verb, [], query_params)

  @doc false
  def registration_path(conn, verb, routes_module \\ __MODULE__), do: routes_module.path_for(conn, RegistrationController, verb)

  @doc """
  Generates a path route.
  """
  @spec path_for(Conn.t(), atom(), atom(), list(), Keyword.t()) :: binary()
  def path_for(conn, plug, verb, vars \\ [], query_params \\ []) do
    gen_route(:path, conn, plug, verb, vars, query_params)
  end

  @doc """
  Generates a url route.
  """
  @spec url_for(Conn.t(), atom(), atom(), list(), Keyword.t()) :: binary()
  def url_for(conn, plug, verb, vars \\ [], query_params \\ []) do
    gen_route(:url, conn, plug, verb, vars, query_params)
  end

  defp gen_route(type, conn, plug, verb, vars, query_params) do
    alias  = Controller.route_helper(plug)
    helper = :"#{alias}_#{type}"
    router = Module.concat([conn.private.phoenix_router, Helpers])
    args   = [conn, verb] ++ vars ++ [query_params]

    apply(router, helper, args)
  end
end
