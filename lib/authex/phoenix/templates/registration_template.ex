defmodule Authex.Phoenix.RegistrationTemplate do
  use Authex.Phoenix.Template

  template :new, :html,
    {:form, [
      {:text, {:module_attribute, :login_field}},
      {:password, :password},
      {:password, :confirm_password}
    ]}

  template :show, :html, """
  <%= inspect(@user) %>
  """

  template :edit, :html,
    {:form, [
      {:password, :current_password},
      {:text, {:module_attribute, :login_field}},
      {:password, :password},
      {:password, :confirm_password}
    ]}
end
