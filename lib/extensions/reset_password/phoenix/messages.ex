defmodule PowResetPassword.Phoenix.Messages do
  @moduledoc false

  @doc """
  Flash message to show when a reset password e-mail has been sent.
  """
  def email_has_been_sent(_conn), do: "An email with reset instructions has been sent to you. Please check your inbox."

  @doc """
  Flash message to show when no user exists for the provided e-mail.
  """
  def user_not_found(_conn), do: "No account exists for the provided email. Please try again."

  @doc """
  Flash message to show when a an invalid or expired reset password link is
  used.
  """
  def invalid_token(_conn), do: "The reset token has expired."

  @doc """
  Flash message to show when password has been updated.
  """
  def password_has_been_reset(_conn), do: "The password has been updated."
end
