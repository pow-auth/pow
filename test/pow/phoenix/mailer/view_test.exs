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

  test "MailView.render/2" do
    assert MailView.subject(:mail, value: "test") == "Subject line"
    html = Phoenix.HTML.safe_to_string(MailView.render("mail.html", value: "test"))
    assert html == "<p>HTML line test</p>"
    assert MailView.render("mail.text", value: "test") == "Text line test"
  end
end
