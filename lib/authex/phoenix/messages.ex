defmodule Authex.Phoenix.Messages do
  @moduledoc """
  Module that handles messages.

  ## Usage

      defmodule MyAppWeb.Authex.Messages do
        use Authex.Phoenix.Messages

        def message(:signed_out, _conn), do: "Signed out successfullly."
      end

    Remember to add `messages_backend:  MyAppWeb.Authex.Messages` to
    your configuration.
  """

  @callback message(:signed_out, Conn.t()) :: binary()
  @callback message(:signed_in, Conn.t()) :: binary()
  @callback message(:invalid_credentials, Conn.t()) :: binary()
  @callback message(:user_has_been_created, Conn.t()) :: binary()
  @callback message(:user_has_been_updated, Conn.t()) :: binary()
  @callback message(:user_has_been_deleted, Conn.t()) :: binary()
  @callback message(:user_could_not_be_deleted, Conn.t()) :: binary()

  defmacro __using__(_opts) do
    quote do
      @behaviour unquote(__MODULE__)

      import unquote(__MODULE__)

      defoverridable unquote(__MODULE__)
    end
  end

  def message(:signed_out, _conn), do: "Signed out successfullly."
  def message(:signed_in, _conn), do: "User successfully signed in."
  def message(:invalid_credentials, _conn), do: "Could not sign in user. Please try again."
  def message(:user_has_been_created, _conn), do: "User has been created successfully."
  def message(:user_has_been_updated, _conn), do: "User has been updated successfully."
  def message(:user_has_been_deleted, _conn), do: "User has been deleted successfully."
  def message(:user_could_not_be_deleted, _conn), do: "User could not be deleted."
end
