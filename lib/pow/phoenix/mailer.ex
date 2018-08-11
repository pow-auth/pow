defmodule Pow.Phoenix.Mailer do
  @moduledoc """
  This module provides an API for mails to be sent by Pow.

  Pow mails is build with `Pow.Phoenix.Mailer.Mail` structs, and consists of
  `:subject`, `:text`, `:html` and `:user` keys.

  ## Usage

      defmodule MyAppWeb.Pow.Mailer do
        use Pow.Phoenix.Mailer
        use Swoosh.Mailer, otp_app: :my_app
        import Swoosh.Email

        def cast(email) do
          %Swoosh.Email{}
          |> from({"My App", "myapp@example.com"})
          |> to({"", email.user.email})
          |> subject(email.subject)
          |> text_body(email.text)
          |> html_body(email.html)
        end

        def process(email), do: deliver(email)
      end

    Remember to update configuration with `mailer_backend: MyAppWeb.Pow.Mailer`
  """
  alias Plug.Conn
  alias Pow.Phoenix.Mailer.Mail

  @callback cast(Mail.t()) :: any()
  @callback process(any()) :: any()

  defmacro __using__(_opts) do
    quote do
      @behaviour unquote(__MODULE__)
    end
  end

  @spec deliver(Conn.t(), Mail.t()) :: any()
  def deliver(conn, email) do
    config = Pow.Plug.fetch_config(conn)
    mailer = Pow.Config.get(config, :mailer_backend, nil) || raise_no_mailer_backend_set()

    email
    |> mailer.cast()
    |> mailer.process()
  end

  @spec raise_no_mailer_backend_set :: no_return
  defp raise_no_mailer_backend_set do
    Pow.Config.raise_error("No :mailer_backend configuration option found for plug.")
  end
end
