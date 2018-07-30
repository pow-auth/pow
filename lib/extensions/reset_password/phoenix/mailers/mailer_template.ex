defmodule PowResetPassword.Phoenix.MailerTemplate do
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
  <%= content_tag(:h3, "Hi,") %>
  <%= content_tag(:p, "Please use the following link to reset your password:") %>
  <%= content_tag(:p, link(@url, to: @url)) %>
  <%= content_tag(:p, "You can disregard this email if you didn't request a password reset.") %>
  """
end
