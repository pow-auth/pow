defmodule AuthexResetPassword.Phoenix.ResetPasswordTemplate do
  use Authex.Phoenix.Template

  template :new, :html,
    {:form, [
      {:text, {:module_attribute, :login_field}}
    ]}

  template :edit, :html,
  {:form, [
    {:password, :password},
    {:password, :confirm_password}
  ]}
end
