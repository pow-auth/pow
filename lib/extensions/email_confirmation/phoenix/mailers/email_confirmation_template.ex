defmodule PowEmailConfirmation.Phoenix.Mailer.EmailConfirmationTemplate do
  @moduledoc false
  use Pow.Phoenix.Mailer.Template

  template :mail,
  "Confirm your email address",
  """
  Hi,

  Please use the following link to confirm your e-mail address:

  <%= @url %>
  """,
  """
  <%= Phoenix.HTML.Tag.content_tag(:h3, "Hi,") %>
  <%= Phoenix.HTML.Tag.content_tag(:p, "Please use the following link to confirm your e-mail address:") %>
  <%= Phoenix.HTML.Tag.content_tag(:p, Phoenix.HTML.Link.link(@url, to: @url)) %>
  """
end
