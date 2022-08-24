defmodule Pow.Phoenix.Mailer.Template do
  @moduledoc """
  Module that builds mailer templates for Phoenix views using EEx with
  `Phoenix.HTML.Engine`.

  ## Usage

      defmodule PowExtension.Phoenix.Mailer.MailTemplate do
        use Pow.Phoenix.Mailer.Template

        template :mail, "Subject line", "Text content", "<p>HTML content</p>"
      end
  """

  @doc false
  defmacro __using__(_opts) do
    quote do
      import unquote(__MODULE__)
      import Phoenix.HTML.{Link, Tag}
    end
  end

  @doc """
  Generate template functions.

  This macro that will compile a mailer template from the provided binaries,
  and add the compiled versions to `render/2` functions. The `text/1` and
  `html/1` outputs the binaries. A `subject/1` function will be added too.
  """
  @spec template(atom(), binary(), binary(), binary()) :: Macro.t()
  defmacro template(action, subject, text, html) do
    quoted_text = EEx.compile_string(text)
    quoted_html = EEx.compile_string(html, engine: Phoenix.HTML.Engine, line: 1, trim: true)

    quote do
      def render(unquote("#{action}.html"), var!(assigns)) do
        _ = var!(assigns)
        unquote(quoted_html)
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
