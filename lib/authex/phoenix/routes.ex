defmodule Authex.Phoenix.Routes do
  @moduledoc """
  Module that handles routes.

  ## Usage

    defmodule MyAppWeb.Authex.Routes do
      use Authex.Phoenix.Routes
      alias MyAppWeb.Router.Helpers, as: Routes

      def after_sign_out_path(conn), do: Routes.some_path(conn, :index)
    end
  """
  alias Plug.Conn
  alias Authex.Phoenix.Controller

  @callback after_sign_out_path(Conn.t()) :: binary()
  @callback after_sign_in_path(Conn.t()) :: binary()
  @callback after_registration_path(Conn.t()) :: binary()
  @callback after_user_updated_path(Conn.t()) :: binary()
  @callback after_user_deleted_path(Conn.t()) :: binary()

  defmacro __using__(_opts) do
    quote do
      @behaviour unquote(__MODULE__)

      import unquote(__MODULE__)

      defoverridable unquote(__MODULE__)
    end
  end

  @spec after_sign_out_path(Conn.t()) :: binary()
  def after_sign_out_path(conn) do
    helpers(conn).authex_session_path(conn, :new)
  end

  @spec after_sign_in_path(Conn.t()) :: binary()
  def after_sign_in_path(_conn), do: "/"

  @spec after_registration_path(Conn.t()) :: binary()
  def after_registration_path(conn), do: after_sign_in_path(conn)

  @spec after_user_updated_path(Conn.t()) :: binary()
  def after_user_updated_path(conn) do
    helpers(conn).authex_registration_path(conn, :edit)
  end

  @spec after_user_deleted_path(Conn.t()) :: binary()
  def after_user_deleted_path(conn), do: after_sign_out_path(conn)

  defp helpers(conn), do: Controller.router_helpers(conn)
end
