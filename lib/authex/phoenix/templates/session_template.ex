defmodule Authex.Phoenix.SessionTemplate do
  use Authex.Phoenix.Template

  template :new, :html,
  """
  <h2>Sign in</h2>

  <%= Authex.Phoenix.HTML.FormTemplate.render([
    {:text, {:module_attribute, :login_field}},
    {:password, :password}
  ],
  button_label: "Sign in") %>

  <span><%%= Phoenix.HTML.Link.link "Register", to: Authex.Phoenix.RouterHelpers.helpers(@conn).authex_registration_path(@conn, :new) %></span>
  """
end
