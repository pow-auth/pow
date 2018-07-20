defmodule PowResetPassword.Phoenix.Mailer.ResetPasswordTemplate do
  use Pow.Phoenix.Mailer.Template

  template :mail,
  "Reset password link",
  """
  Hi,

  Please use the following link to reset your password:

  <%= @url %>

  You can disregard this email if you didn't request a password reset.
  """,
  """
  <%= Phoenix.HTML.Tag.content_tag(:h3, "Hi,") %>
  <%= Phoenix.HTML.Tag.content_tag(:p, "Please use the following link to reset your password:") %>
  <%= Phoenix.HTML.Tag.content_tag(:p, Phoenix.HTML.Link.link(@url, to: @url)) %>
  <%= Phoenix.HTML.Tag.content_tag(:p, "You can disregard this email if you didn't request a password reset.") %>
  """
end
