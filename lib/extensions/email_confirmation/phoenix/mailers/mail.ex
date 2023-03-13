defmodule PowEmailConfirmation.Phoenix.Mail do
  @moduledoc false
  use Pow.Phoenix.Mailer.Template

  template :email_confirmation,
  "Confirm your email address",
  """
  Hi,

  Please use the following link to confirm your e-mail address:

  <%= @url %>
  """,
  """
  <h3>Hi</h3>
  <p>Please use the following link to confirm your e-mail address:</p>
  <p><a href="<%= @url %>"><%= @url %></a></p>
  """
end
