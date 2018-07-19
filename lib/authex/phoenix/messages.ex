defmodule Authex.Phoenix.Messages do
  @moduledoc """
  Module that handles messages.

  ## Usage

      defmodule MyAppWeb.Authex.Messages do
        use Authex.Phoenix.Messages

        def signed_out(_conn), do: "Signed out successfullly."
      end

    Remember to add `messages_backend:  MyAppWeb.Authex.Messages` to
    your configuration.
  """
  @callback signed_out(Conn.t()) :: binary()
  @callback signed_in(Conn.t()) :: binary()
  @callback invalid_credentials(Conn.t()) :: binary()
  @callback user_has_been_created(Conn.t()) :: binary()
  @callback user_has_been_updated(Conn.t()) :: binary()
  @callback user_has_been_deleted(Conn.t()) :: binary()
  @callback user_could_not_be_deleted(Conn.t()) :: binary()

  defmacro __using__(_opts) do
    quote do
      @behaviour unquote(__MODULE__)

      def signed_out(conn),
        do: unquote(__MODULE__).signed_out(conn)
      def signed_in(conn),
        do: unquote(__MODULE__).signed_in(conn)
      def invalid_credentials(conn),
        do: unquote(__MODULE__).invalid_credentials(conn)
      def user_has_been_created(conn),
        do: unquote(__MODULE__).user_has_been_created(conn)
      def user_has_been_updated(conn),
        do: unquote(__MODULE__).user_has_been_updated(conn)
      def user_has_been_deleted(conn),
        do: unquote(__MODULE__).user_has_been_deleted(conn)
      def user_could_not_be_deleted(conn),
        do: unquote(__MODULE__).user_could_not_be_deleted(conn)

      defoverridable unquote(__MODULE__)
    end
  end

  def signed_out(_conn), do: "Signed out successfullly."
  def signed_in(_conn), do: "User successfully signed in."
  def invalid_credentials(_conn), do: "Could not sign in user. Please try again."
  def user_has_been_created(_conn), do: "User has been created successfully."
  def user_has_been_updated(_conn), do: "User has been updated successfully."
  def user_has_been_deleted(_conn), do: "User has been deleted successfully."
  def user_could_not_be_deleted(_conn), do: "User could not be deleted."
end
