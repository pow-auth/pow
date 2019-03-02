defmodule PowResetPassword.Phoenix.ResetPasswordTemplate do
  @moduledoc false
  use Pow.Phoenix.Template

  template :new, :html,
  """
  <h1>Reset password</h1>

  <%= Pow.Phoenix.HTML.FormTemplate.render([
    {:text, {:changeset, :pow_user_id_field}}
  ]) %>
  """

  template :edit, :html,
  """
  <h1>Reset password</h1>

  <%= Pow.Phoenix.HTML.FormTemplate.render([
    {:password, :password},
    {:password, :confirm_password}
  ]) %>

  <span><%%= link "Sign in", to: Routes.<%= Pow.Phoenix.Controller.route_helper(Pow.Phoenix.SessionController) %>_path(@conn, :new) %></span>
  """
end
