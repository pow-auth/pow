defmodule Authex.Test.Phoenix.LayoutView do
  use Authex.Test.Phoenix.Web, :view
end
defmodule Authex.Test.Phoenix.SessionView do
  use Authex.Test.Phoenix.Web, :view
end
defmodule Authex.Test.Phoenix.ErrorView do
  def render("500.html", _assigns), do: "500.html"
  def render("400.html", _assigns), do: "400.html"
  def render("404.html", _assigns), do: "404.html"
end
