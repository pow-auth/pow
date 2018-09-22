defmodule PowResetPassword.Phoenix.ResetPasswordTemplate do
  @moduledoc false
  use Pow.Phoenix.Template

  template :new, :html,
  """
  <h2>Reset password</h2>

  <%= Pow.Phoenix.HTML.FormTemplate.render([
    {:text, {:changeset, :pow_user_id_field}}
  ]) %>
  """

  template :edit, :html,
  """
  <h2>Reset password</h2>

  <%= Pow.Phoenix.HTML.FormTemplate.render([
    {:password, :password},
    {:password, :confirm_password}
  ]) %>

  <span><%%= link "Sign in", to: @new_session_path %></span>
  """
end
