defmodule Authex.Phoenix.RegistrationTemplate do
  use Authex.Phoenix.Template

  template :new, :html,
  """
  <h2>Register</h2>

  <%= Authex.Phoenix.HTML.FormTemplate.render([
    {:text, {:module_attribute, :login_field}},
    {:password, :password},
    {:password, :confirm_password}
  ]) %>
  """

  template :edit, :html,
  """
  <h2>Edit profile</h2>

  <%= Authex.Phoenix.HTML.FormTemplate.render([
    {:password, :current_password},
    {:text, {:module_attribute, :login_field}},
    {:password, :password},
    {:password, :confirm_password}
  ]) %>
  """
end
