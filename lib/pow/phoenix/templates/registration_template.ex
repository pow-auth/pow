defmodule Pow.Phoenix.RegistrationTemplate do
  @moduledoc false
  use Pow.Phoenix.Template

  template :new, :html,
  """
  <h1>Register</h1>

  <%= Pow.Phoenix.HTML.FormTemplate.render([
    {:text, {:changeset, :pow_user_id_field}},
    {:password, :password},
    {:password, :password_confirmation}
  ],
  button_label: "Register") %>

  <span><%%= link "Sign in", to: Routes.<%= Pow.Phoenix.Controller.route_helper(Pow.Phoenix.SessionController) %>_path(@conn, :new) %></span>
  """

  template :edit, :html,
  """
  <h1>Edit profile</h1>

  <%= Pow.Phoenix.HTML.FormTemplate.render([
    {:password, :current_password},
    {:text, {:changeset, :pow_user_id_field}},
    {:password, :password},
    {:password, :password_confirmation}
  ],
  button_label: "Update") %>
  """
end
