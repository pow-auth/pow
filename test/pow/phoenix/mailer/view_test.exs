defmodule Pow.Phoenix.Mailer.ViewTest.MailTemplate do
  use Pow.Phoenix.Mailer.Template

  template :mail,
    "Subject line",
    "Text line <%= @value %>",
    "<p>HTML line <%= @value %></p>"
end
defmodule Pow.Phoenix.Mailer.ViewTest.MailView do
  use Pow.Phoenix.Mailer.View
end

defmodule Pow.Phoenix.Mailer.ViewTest do
  use ExUnit.Case
  doctest Pow.Phoenix.Mailer.View

  alias Pow.Phoenix.Mailer.ViewTest.MailView

  test "render/2" do
    assert MailView.render("mail.html", value: "test") == "<p>HTML line test</p>"
    assert MailView.render("mail.text", value: "test") == "Text line test"
    assert MailView.subject(:mail) == "Subject line"
  end
end
