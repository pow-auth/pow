defmodule Pow.Phoenix.Routes do
  @moduledoc """
  Module that handles routes.

  ## Usage

    defmodule MyAppWeb.Pow.Routes do
      use Pow.Phoenix.Routes
      alias MyAppWeb.Router.Helpers, as: Routes

      def after_sign_out_path(conn), do: Routes.some_path(conn, :index)
    end
  """
  alias Plug.Conn
  alias Pow.Phoenix.Controller

  @callback after_sign_out_path(Conn.t()) :: binary()
  @callback after_sign_in_path(Conn.t()) :: binary()
  @callback after_registration_path(Conn.t()) :: binary()
  @callback after_user_updated_path(Conn.t()) :: binary()
  @callback after_user_deleted_path(Conn.t()) :: binary()

  defmacro __using__(_opts) do
    quote do
      @behaviour unquote(__MODULE__)

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

  def after_sign_out_path(conn) do
    Controller.router_helpers(conn).pow_session_path(conn, :new)
  end

  def after_sign_in_path(_conn), do: "/"

  def after_registration_path(conn), do: after_sign_in_path(conn)

  def after_user_updated_path(conn) do
    Controller.router_helpers(conn).pow_registration_path(conn, :edit)
  end

  def after_user_deleted_path(conn), do: after_sign_out_path(conn)
end
