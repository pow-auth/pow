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
end
