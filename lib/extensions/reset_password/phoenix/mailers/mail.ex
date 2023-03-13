defmodule PowResetPassword.Phoenix.Mail do
  @moduledoc false
  use Pow.Phoenix.Mailer.Template

  template :reset_password,
  "Reset password link",
  """
  Hi,

  Please use the following link to reset your password:

  <%= @url %>

  You can disregard this email if you didn't request a password reset.
  """,
  """
  <h3>Hi,</h3>
  <p>Please use the following link to reset your password:</p>
  <p><a href="<%= @url %>"><%= @url %></a></p>
  <p>You can disregard this email if you didn't request a password reset.</p>
  """
end
