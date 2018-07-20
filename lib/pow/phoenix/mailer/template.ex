defmodule Pow.Phoenix.Mailer.Template do
  @moduledoc """
  Module that can builds mailer templates for Phoenix views using
  EEx with Phoenix.HTML.Engine.

  Example:

    defmodule MyAppWeb.Mailer.MailTemplate do
      use Pow.Phoenix.Mailer.Template

      template :mail, "Subject line", "Text content", "<p>HTML content</p>"
    end

    MyAppWeb.Mailer.MailTemplate.render("mail.html", assigns)
  """
  defmacro __using__(_opts) do
    quote do
      import unquote(__MODULE__)
    end
  end

  @spec template(atom(), binary(), binary(), binary()) :: Macro.t()
  defmacro template(action, subject, text, html) do
    quoted_text = EEx.compile_string(text)
    quoted_html = EEx.compile_string(html, engine: Phoenix.HTML.Engine, line: 1, trim: true)

    quote do
      def render(unquote("#{action}.html"), var!(assigns)) do
        _ = var!(assigns)
        unquote(quoted_html)
        |> Phoenix.Template.HTML.encode_to_iodata!()
        |> IO.iodata_to_binary()
      end

      def render(unquote("#{action}.text"), var!(assigns)) do
        _ = var!(assigns)
        unquote(quoted_text)
      end

      def text(unquote(action)), do: unquote(text)
      def html(unquote(action)), do: unquote(html)
      def subject(unquote(action)), do: unquote(subject)
    end
  end
end
