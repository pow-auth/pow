defmodule Pow.Phoenix.Messages do
  @moduledoc """
  Module that handles messages.

  ## Usage

      defmodule MyAppWeb.Pow.Messages do
        use Pow.Phoenix.Messages

        def signed_out(_conn), do: "Signed out successfullly."
      end

    Remember to add `messages_backend: MyAppWeb.Pow.Messages` to your
    configuration.
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

      def user_not_authenticated(conn),
        do: unquote(__MODULE__).user_not_authenticated(conn)
      def user_already_authenticated(conn),
        do: unquote(__MODULE__).user_already_authenticated(conn)
      def signed_in(conn),
        do: unquote(__MODULE__).signed_in(conn)
      def signed_out(conn),
        do: unquote(__MODULE__).signed_out(conn)
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

  def user_not_authenticated(_conn), do: "You need to sign in to see this page."
  def user_already_authenticated(_conn), do: "You're already signed in."
  def signed_in(_conn), do: "Welcome! You've been signed in."
  def signed_out(_conn), do: "You've been signed out. See you soon!"
  def invalid_credentials(_conn), do: "The provided login details did not work. Please verify your credentials, and try again."
  def user_has_been_created(_conn), do: "Welcome! Your account has been created."
  def user_has_been_updated(_conn), do: "Your account has been updated."
  def user_has_been_deleted(_conn), do: "Your account has been deleted. Sorry to see you go!"
  def user_could_not_be_deleted(_conn), do: "Something went wrong. Your account could not be deleted."
end
