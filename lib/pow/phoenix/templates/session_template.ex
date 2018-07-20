defmodule Pow.Phoenix.SessionTemplate do
  use Pow.Phoenix.Template

  template :new, :html,
  """
  <h2>Sign in</h2>

  <%= Pow.Phoenix.HTML.FormTemplate.render([
    {:text, {:module_attribute, :login_field}},
    {:password, :password}
  ],
  button_label: "Sign in") %>

  <span><%%= Phoenix.HTML.Link.link "Register", to: Pow.Phoenix.Controller.router_helpers(@conn).pow_registration_path(@conn, :new) %></span>
  """
end
