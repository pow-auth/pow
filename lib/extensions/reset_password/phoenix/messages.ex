defmodule PowResetPassword.Phoenix.Messages do
  def email_has_been_sent(_conn), do: "An email with reset instructions has been sent to you. Please check your inbox."
  def invalid_token(_conn), do: "The reset token has expired."
  def password_has_been_reset(_conn), do: "The password has been updated."
end
