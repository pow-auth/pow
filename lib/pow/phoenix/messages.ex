defmodule Pow.Phoenix.Messages do
  @moduledoc """
  Module that handles messages.

  ## Usage

      defmodule MyAppWeb.Pow.Messages do
        use Pow.Phoenix.Messages
        import MyAppWeb.Gettext

        def signed_out(_conn), do: gettext("Signed out successfullly.")
      end

  Remember to add `messages_backend: MyAppWeb.Pow.Messages` to your
  configuration.
  """
  alias Plug.Conn

  @type message :: binary() | nil

  @callback user_not_authenticated(Conn.t()) :: message()
  @callback user_already_authenticated(Conn.t()) :: message()
  @callback signed_out(Conn.t()) :: message()
  @callback signed_in(Conn.t()) :: message()
  @callback invalid_credentials(Conn.t()) :: message()
  @callback user_has_been_created(Conn.t()) :: message()
  @callback user_has_been_updated(Conn.t()) :: message()
  @callback user_has_been_deleted(Conn.t()) :: message()
  @callback user_could_not_be_deleted(Conn.t()) :: message()

  @doc false
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

  @doc """
  Message for when user is not authenticated.

  Defaults to nil.
  """
  def user_not_authenticated(_conn), do: nil

  @doc """
  Message for when user is already authenticated.

  Defaults to nil.
  """
  def user_already_authenticated(_conn), do: nil

  @doc """
  Message for when user has signed in.

  Defaults to nil.
  """
  def signed_in(_conn), do: nil

  @doc """
  Message for when user has signed out.

  Defaults to nil.
  """
  def signed_out(_conn), do: nil

  @doc """
  Message for when user couldn't be signed in.
  """
  def invalid_credentials(_conn),
    do: "The provided login details did not work. Please verify your credentials, and try again."

  @doc """
  Message for when user has signed up successfully.

  Defaults to nil.
  """
  def user_has_been_created(_conn), do: nil

  @doc """
  Message for when user has updated their account successfully.
  """
  def user_has_been_updated(_conn), do: "Your account has been updated."

  @doc """
  Message for when user has deleted their account successfully.
  """
  def user_has_been_deleted(_conn), do: "Your account has been deleted. Sorry to see you go!"

  @doc """
  Message for when account could not be deleted.
  """
  def user_could_not_be_deleted(_conn), do: "Your account could not be deleted."
end
