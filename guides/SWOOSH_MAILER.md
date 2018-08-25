# Swoosh mailer

You can easily set up the mailer to use [Swoosh](https://github.com/swoosh/swoosh).

First be sure that you've set up and configured Swoosh with your app. Then set up your `WEB_PATH/pow_mailer.ex` file like so:

```elixir
defmodule MyAppWeb.PowMailer do
  use Pow.Phoenix.Mailer
  use Swoosh.Mailer, otp_app: :my_app

  import Swoosh.Email

  def cast(%{user: user, subject: subject, text: text, html: html}) do
    %Swoosh.Email{}
    |> to({"", user.email})
    |> from({"My App", "myapp@example.com"})
    |> subject(subject)
    |> html_body(html)
    |> text_body(text)
  end

  def process(email) do
    deliver(email)
  end
end
```

Remember to add `mailer_backend: MyAppWeb.PowMailer` to the Pow configuration.