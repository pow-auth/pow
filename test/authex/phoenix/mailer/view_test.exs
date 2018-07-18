defmodule Authex.Phoenix.Mailer.ViewTest.MailTemplate do
  use Authex.Phoenix.Mailer.Template

  template :mail,
    "Subject line",
    "Text line <%= @value %>",
    "<p>HTML line <%= @value %></p>"
end
defmodule Authex.Phoenix.Mailer.ViewTest.MailView do
  use Authex.Phoenix.Mailer.View
end

defmodule Authex.Phoenix.Mailer.ViewTest do
  use ExUnit.Case
  doctest Authex.Phoenix.Mailer.View

  alias Authex.Phoenix.Mailer.ViewTest.MailView

  test "render/2" do
    assert MailView.render("mail.html", value: "test") == "<p>HTML line test</p>"
    assert MailView.render("mail.text", value: "test") == "Text line test"
    assert MailView.subject(:mail) == "Subject line"
  end
end
