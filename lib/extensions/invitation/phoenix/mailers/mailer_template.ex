defmodule PowInvitation.Phoenix.MailerTemplate do
  @moduledoc false
  use Pow.Phoenix.Mailer.Template

  template :invitation,
  "You've been invited",
  """
  Hi,

  You've been invited by <%= @invited_by_user_id %>. Please use the following link to accept your invitation:

  <%= @url %>
  """,
  """
  <%= content_tag(:h3, "Hi,") %>
  <%= content_tag(:p, "You've been invited by \#{@invited_by_user_id}. Please use the following link to accept your invitation:") %>
  <%= content_tag(:p, link(@url, to: @url)) %>
  """
end
