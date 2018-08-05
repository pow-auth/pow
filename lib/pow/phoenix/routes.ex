defmodule Pow.Phoenix.Routes do
  @moduledoc """
  Module that handles routes.

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

  @doc """
  Path to redirect user to when user is not authenticated.

  This will put a `:request_path` param into the path that can be used to
  redirect users back the the page they first attempted to visit. See
  `after_sign_in_path/1` for how `:request_path` is handled.

  See `Pow.Phoenix.SessionController` for more on how this value is handled.
  """
  def user_not_authenticated_path(conn) do
    Controller.router_helpers(conn).pow_session_path(conn, :new, request_path: Phoenix.Controller.current_path(conn))
  end

  @doc """
  Path to redirect user to when user has already been authenticated.

  By default this is the same as `after_sign_in_path/1`.
  """
  def user_already_authenticated_path(conn), do: after_sign_in_path(conn)

  @doc """
  Path to redirect user to when user has signed out.
  """
  def after_sign_out_path(conn) do
    Controller.router_helpers(conn).pow_session_path(conn, :new)
  end

  @doc """
  Path to redirect user to when user has signed in.

  This will look for a `:request_path` assigns key, and redirect to this value
  if it exists.
  """
  def after_sign_in_path(%{assigns: %{request_path: request_path}}) when is_binary(request_path), do: request_path
  def after_sign_in_path(_params), do: "/"

  @doc """
  Path to redirect user to when user has signed up.

  By default this is the same as `after_sign_in_path/1`.
  """
  def after_registration_path(conn), do: after_sign_in_path(conn)

  @doc """
  Path to redirect user to when user has updated their account.
  """
  def after_user_updated_path(conn) do
    Controller.router_helpers(conn).pow_registration_path(conn, :edit)
  end

  @doc """
  Path to redirect user to when user has deleted their account.

  By default this is the same as `after_sign_out_path/1`.
  """
  def after_user_deleted_path(conn), do: after_sign_out_path(conn)
end
