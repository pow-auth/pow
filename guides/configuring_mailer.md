# Configuring mailer

You are able to configure a mailer for Pow and set it up with the library of 
your choice.

This guide shows how to setup Pow with

 * [Swoosh](https://github.com/swoosh/swoosh)
 * [Bamboo](https://github.com/thoughtbot/bamboo)

You must first setup and configure either of these libraries before you can
integrate them with Pow.

## Swoosh mailer

Set up your `WEB_PATH/pow_mailer.ex` file like so:

```elixir
defmodule MyAppWeb.PowMailer do
  use Pow.Phoenix.Mailer
  use Swoosh.Mailer, otp_app: :my_app

  import Swoosh.Email
  
  require Logger

  def cast(%{user: user, subject: subject, text: text, html: html}) do
    %Swoosh.Email{}
    |> to({"", user.email})
    |> from({"My App", "myapp@example.com"})
    |> subject(subject)
    |> html_body(html)
    |> text_body(text)
  end

  def process(email) do
    email
    |> deliver()
    |> log_warnings()
  end

  defp log_warnings({:error, reason}) do
    Logger.warn("Mailer backend failed with: #{inspect(reason)}")
  end

  defp log_warnings({:ok, response}), do: {:ok, response}
end
```

Remember to add `mailer_backend: MyAppWeb.PowMailer` to the Pow configuration.

## Bamboo mailer

Set up your `WEB_PATH/pow_mailer.ex` file like so:

```elixir
defmodule MyAppWeb.PowMailer do
  use Pow.Phoenix.Mailer
  use Bamboo.Mailer, otp_app: :my_app

  import Bamboo.Email
  
  require Logger

  def cast(%{user: user, subject: subject, text: text, html: html}) do
    new_email
    |> to(user.email)
    |> from("myapp@example.com")
    |> subject(subject)
    |> html_body(html)
    |> text_body(text)
  end

  def process(email) do
    email
    |> deliver_now()   
  end


end
```

Remember to add `mailer_backend: MyAppWeb.PowMailer` to the Pow configuration.
