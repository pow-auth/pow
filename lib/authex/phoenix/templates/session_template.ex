defmodule Authex.Phoenix.SessionTemplate do
  use Authex.Phoenix.Template

  template :new, :html, """
  <%= unquote(Authex.Phoenix.HTML.form(:session, :new)) %>
  """
end
