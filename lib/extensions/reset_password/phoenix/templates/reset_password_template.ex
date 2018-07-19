defmodule AuthexResetPassword.Phoenix.ResetPasswordTemplate do
  use Authex.Phoenix.Template

  template :new, :html,
  """
  <h2>Reset password</h2>

  <%= Authex.Phoenix.HTML.FormTemplate.render([
    {:text, {:module_attribute, :login_field}}
  ]) %>
  """

  template :edit, :html,
  """
  <h2>Reset password</h2>

  <%= Authex.Phoenix.HTML.FormTemplate.render([
    {:password, :password},
    {:password, :confirm_password}
  ]) %>

  <span><%%= Phoenix.HTML.Link.link "Sign in", to: Authex.Phoenix.Controller.router_helpers(@conn).authex_session_path(@conn, :new) %></span>
  """
end
