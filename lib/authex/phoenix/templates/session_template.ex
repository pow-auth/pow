defmodule Authex.Phoenix.SessionTemplate do
  use Authex.Phoenix.Template

  template :new, :html,
    {:form, [
      {:text, {:module_attribute, :login_field}},
      {:password, :password}
    ]}
end
