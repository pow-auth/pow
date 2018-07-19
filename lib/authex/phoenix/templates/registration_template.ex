defmodule Authex.Phoenix.RegistrationTemplate do
  use Authex.Phoenix.Template

  template :new, :html,
  """
  <h2>Register</h2>

  <%= Authex.Phoenix.HTML.FormTemplate.render([
    {:text, {:module_attribute, :login_field}},
    {:password, :password},
    {:password, :confirm_password}
  ],
  button_label: "Register") %>

  <span><%%= Phoenix.HTML.Link.link "Sign in", to: Authex.Phoenix.Controller.router_helpers(@conn).authex_session_path(@conn, :new) %></span>
  """

  template :edit, :html,
  """
  <h2>Edit profile</h2>

  <%= Authex.Phoenix.HTML.FormTemplate.render([
    {:password, :current_password},
    {:text, {:module_attribute, :login_field}},
    {:password, :password},
    {:password, :confirm_password}
  ],
  button_label: "Update") %>
  """
end
