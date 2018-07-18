defmodule Authex.Phoenix.SessionTemplate do
  use Authex.Phoenix.Template

  template :new, :html,
  """
  <h2>Sign in</h2>

  <%= Authex.Phoenix.HTML.FormTemplate.render([
    {:text, {:module_attribute, :login_field}},
    {:password, :password}
  ]) %>
  """
end
