defmodule PowResetPassword.Phoenix.ResetPasswordTemplate do
  use Pow.Phoenix.Template

  template :new, :html,
  """
  <h2>Reset password</h2>

  <%= Pow.Phoenix.HTML.FormTemplate.render([
    {:text, {:module_attribute, :login_field}}
  ]) %>
  """

  template :edit, :html,
  """
  <h2>Reset password</h2>

  <%= Pow.Phoenix.HTML.FormTemplate.render([
    {:password, :password},
    {:password, :confirm_password}
  ]) %>

  <span><%%= Phoenix.HTML.Link.link "Sign in", to: Pow.Phoenix.Controller.router_helpers(@conn).pow_session_path(@conn, :new) %></span>
  """
end
