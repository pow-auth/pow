defmodule Pow.Phoenix.SessionTemplate do
  @moduledoc false
  use Pow.Phoenix.Template

  template :new, :html,
  """
  <h1>Sign in</h1>

  <%= Pow.Phoenix.HTML.FormTemplate.render([
    {:text, {:changeset, :pow_user_id_field}},
    {:password, :password}
  ],
  button_label: "Sign in") %>

  <span><%%= Phoenix.HTML.Link.link "Register", to: Pow.Phoenix.Controller.router_helpers(@conn).pow_registration_path(@conn, :new) %></span>
  """
end
