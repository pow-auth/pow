defmodule Pow.Phoenix.Routes do
  @moduledoc """
  Module that handles routes.

  The `user_not_authenticated_path` method  will put a `:request_path` param
  into the path that can be used to redirect users back the the page they first
  attempted to visit. The `after_sign_in_path` method will look for a
  `:request_path` assigns key, and redirect to this value if it exists.

  If the `:request_path` param is available to the `:new` or `:create` actions
  in `Pow.Phoenix.SessionController`, the controller will automatically assign
  a `:request_path` key. If there's a `:request_path` assigns key, the
  `pow_session_path(conn, :create)` will be generated with a `:request_path`
  param.

  ## Usage

      defmodule MyAppWeb.Pow.Routes do
        use Pow.Phoenix.Routes
        alias MyAppWeb.Router.Helpers, as: Routes

        def after_sign_out_path(conn), do: Routes.some_path(conn, :index)
      end

    Update configuration with `routes_backend: MyAppWeb.Pow.Routes`.
  """
  alias Plug.Conn
  alias Pow.Phoenix.Controller

  @callback user_not_authenticated_path(Conn.t()) :: binary()
  @callback user_already_authenticated_path(Conn.t()) :: binary()
  @callback after_sign_out_path(Conn.t()) :: binary()
  @callback after_sign_in_path(Conn.t()) :: binary()
  @callback after_registration_path(Conn.t()) :: binary()
  @callback after_user_updated_path(Conn.t()) :: binary()
  @callback after_user_deleted_path(Conn.t()) :: binary()

  defmacro __using__(_opts) do
    quote do
      @behaviour unquote(__MODULE__)

      def user_not_authenticated_path(conn),
        do: unquote(__MODULE__).user_not_authenticated_path(conn)
      def user_already_authenticated_path(conn),
        do: unquote(__MODULE__).user_already_authenticated_path(conn)
      def after_sign_out_path(conn),
        do: unquote(__MODULE__).after_sign_out_path(conn)
      def after_sign_in_path(conn),
        do: unquote(__MODULE__).after_sign_in_path(conn)
      def after_registration_path(conn),
        do: unquote(__MODULE__).after_registration_path(conn)
      def after_user_updated_path(conn),
        do: unquote(__MODULE__).after_user_updated_path(conn)
      def after_user_deleted_path(conn),
        do: unquote(__MODULE__).after_user_deleted_path(conn)

      defoverridable unquote(__MODULE__)
    end
  end

  def user_not_authenticated_path(conn) do
    Controller.router_helpers(conn).pow_session_path(conn, :new, request_path: Phoenix.Controller.current_path(conn))
  end

  def user_already_authenticated_path(conn), do: after_sign_in_path(conn)

  def after_sign_out_path(conn) do
    Controller.router_helpers(conn).pow_session_path(conn, :new)
  end

  def after_sign_in_path(%{assigns: %{request_path: request_path}}) when is_binary(request_path), do: request_path
  def after_sign_in_path(_params), do: "/"

  def after_registration_path(conn), do: after_sign_in_path(conn)

  def after_user_updated_path(conn) do
    Controller.router_helpers(conn).pow_registration_path(conn, :edit)
  end

  def after_user_deleted_path(conn), do: after_sign_out_path(conn)
end
