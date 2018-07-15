defmodule Authex.Phoenix.RegistrationTemplate do
  use Authex.Phoenix.Template

  template :new, :html, """
  <%= unquote(Authex.Phoenix.HTML.form(:registration, :new)) %>
  """

  template :show, :html, """
  <%= inspect(@user) %>
  """

  template :edit, :html, """
  <%= unquote(Authex.Phoenix.HTML.form(:registration, :edit)) %>
  """
end
