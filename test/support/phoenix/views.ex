defmodule Pow.Test.Phoenix.LayoutView do
  use Pow.Test.Phoenix.Web, :view
end
defmodule Pow.Test.Phoenix.Pow.SessionView do
  use Pow.Test.Phoenix.Web, :context_app_view
end
defmodule Pow.Test.Phoenix.ErrorView do
  def render("500.html", _assigns), do: "500.html"
  def render("400.html", _assigns), do: "400.html"
  def render("404.html", _assigns), do: "404.html"
end
