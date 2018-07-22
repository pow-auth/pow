defmodule Pow.Phoenix.RegistrationTemplate do
  @moduledoc false
  use Pow.Phoenix.Template

  template :new, :html,
  """
  <h2>Register</h2>

  <%= Pow.Phoenix.HTML.FormTemplate.render([
    {:text, {:module_attribute, :user_id_field}},
    {:password, :password},
    {:password, :confirm_password}
  ],
  button_label: "Register") %>

  <span><%%= Phoenix.HTML.Link.link "Sign in", to: Pow.Phoenix.Controller.router_helpers(@conn).pow_session_path(@conn, :new) %></span>
  """

  template :edit, :html,
  """
  <h2>Edit profile</h2>

  <%= Pow.Phoenix.HTML.FormTemplate.render([
    {:password, :current_password},
    {:text, {:module_attribute, :user_id_field}},
    {:password, :password},
    {:password, :confirm_password}
  ],
  button_label: "Update") %>
  """
end
