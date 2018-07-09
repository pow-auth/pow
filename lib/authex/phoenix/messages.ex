defmodule Authex.Phoenix.Messages do
  @moduledoc """
  Module that handles messages.
  """

  @spec signed_out() :: binary()
  def signed_out, do: "Signed out successfullly."

  @spec signed_in() :: binary()
  def signed_in, do: "User successfully signed in."

  @spec invalid_credentials() :: binary()
  def invalid_credentials, do: "Could not sign in user. Please try again."

  @spec user_has_been_created() :: binary()
  def user_has_been_created, do: "User has been created successfully."

  @spec user_has_been_updated() :: binary()
  def user_has_been_updated, do: "User has been updated successfully."

  @spec user_has_been_deleted() :: binary()
  def user_has_been_deleted, do: "User has been deleted successfully."
end
