defmodule AuthexResetPassword.Phoenix.Messages do
  @spec email_has_been_sent() :: binary()
  def email_has_been_sent, do: "An email with reset instructions has been sent to you. Please check your inbox."

  @spec invalid_token() :: binary()
  def invalid_token, do: "The reset token has expired."

  @spec password_has_been_reset() :: binary()
  def password_has_been_reset, do: "The password has been updated."
end
