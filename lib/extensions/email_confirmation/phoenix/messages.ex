defmodule PowEmailConfirmation.Phoenix.Messages do
  @moduledoc """
  Module that handles messages for PowEmailConfirmation.

  See `Pow.Extension.Phoenix.Messages` for more.
  """

  @doc """
  Flash message to show when email has been confirmed.
  """
  def email_has_been_confirmed(_conn), do: "The email address has been confirmed."

  @doc """
  Flash message to show when email couldn't be confirmed.
  """
  def email_confirmation_failed(_conn), do: "The email address couldn't be confirmed."


  @doc """
  Flash message to show when a invalid confirmation link is used.
  """
  def invalid_token(_conn), do: "The confirmation token is invalid or has expired."

  @doc """
  Flash message to show when user is signs in or registers but e-mail is yet
  to be confirmed.
  """
  def email_confirmation_required(_conn), do: "You'll need to confirm your e-mail before you can sign in. An e-mail confirmation link has been sent to you."

  @doc """
  Flash message to show when user updates their e-mail and requires
  confirmation.
  """
  def email_confirmation_required_for_update(_conn), do: "You'll need to confirm the e-mail before it's updated. An e-mail confirmation link has been sent to you."
end
