defmodule PowInvitation.Phoenix.Messages do
  @moduledoc """
  Module that handles messages for PowInvitation.

  See `Pow.Extension.Phoenix.Messages` for more.
  """

  @doc """
  Flash message to show when an invalid or expired invitation url is used.
  """
  def invalid_invitation(_conn), do: "The invitation doesn't exist."

  @doc """
  Flash message to show when user has been invited and e-mail has been sent.
  """
  def invitation_email_sent(_conn), do: "An e-mail with invitation link has been sent."
end
