defmodule PowInvitation.Phoenix.InvitationHTML do
  @moduledoc false
  use Pow.Phoenix.Template

  template :new, :html,
  """
  <h1>Invite</h1>

  <%= Pow.Phoenix.HTML.FormTemplate.render([
    {:text, {:changeset, :pow_user_id_field}}
  ]) %>
  """

  template :edit, :html,
  """
  <h1>Register</h1>

  <%= Pow.Phoenix.HTML.FormTemplate.render([
    {:text, {:changeset, :pow_user_id_field}},
    {:password, :password},
    {:password, :password_confirmation}
  ]) %>

  <span><%%= link "Sign in", to: <%= Pow.Phoenix.Template.__inline_route__(Pow.Phoenix.SessionController, :new) %> %></span>
  """

  template :show, :html,
  """
  <h1>Invitation</h1>

  <blockquote><%%= @url %></blockquote>
  """
end
