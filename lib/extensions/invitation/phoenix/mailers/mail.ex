defmodule PowInvitation.Phoenix.Mail do
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
  <h3>Hi,</h3>
  <p>You've been invited by <strong><%= @invited_by_user_id %></strong>. Please use the following link to accept your invitation:</p>
  <p><a href="<%= @url %>"><%= @url %></a></p>
  """
end
