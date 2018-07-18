defmodule Authex.Phoenix.Mailer do
  @moduledoc """
  This is a mailer module that provides an API for any
  mails that Authex might need to sent.

  ## Usage

    defmodule MyAppWeb.Mailer do
      use Authex.Phoenix.Mailer
      use Swoosh.Mailer, otp_app: :my_app

      def cast(email) do
        new()
        |> from({"My App", "myapp@example.com"})
        |> to({"", user.email})
        |> subject(email.subject)
        |> text_body(email.text)
        |> html_body(email.html)
      end

      def process(email), do: deliver(email)
    end
  """
  alias Plug.Conn
  alias Authex.Phoenix.Mailer.Mail

  @callback cast(Mail.t()) :: any()
  @callback process(any()) :: any()

  defmacro __using__(_opts) do
    quote do
      @behaviour unquote(__MODULE__)
    end
  end

  @spec deliver(Conn.t(), Mail.t()) :: any()
  def deliver(conn, email) do
    config = Authex.Plug.fetch_config(conn)
    mailer = Authex.Config.get(config, :mailer, nil) || raise_no_mailer_set()

    email
    |> mailer.cast()
    |> mailer.process()
  end

  @spec raise_no_mailer_set() :: no_return
  defp raise_no_mailer_set() do
    Authex.Config.raise_error("No :mailer configuration option found for plug.")
  end
end
