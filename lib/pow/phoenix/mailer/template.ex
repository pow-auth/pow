defmodule Pow.Phoenix.Mailer.Template do
  @moduledoc """
  Module that builds mailer templates for Phoenix templates using EEx with
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
      use Pow.Phoenix.Mailer.Component
      import unquote(__MODULE__)

      # Credo will complain about unless statement but we want this first
      # credo:disable-for-next-line
      unless Pow.dependency_vsn_match?(:phoenix, "< 1.7.0") do
        quote do
          use Phoenix.Component
        end
      else
        # TODO: Remove when Phoenix 1.7 is required
        quote do
          import Phoenix.HTML.{Form, Link}
        end
      end
    end
  end

  defstruct [:subject, :text, :html]

  @doc """
  Generate template functions.

  This macro that will compile a mailer template from the provided binaries,
  and add the compiled versions to `render/2` functions. The `text/1` and
  `html/1` outputs the binaries. A `subject/1` function will be added too.
  """
  @spec template(atom(), binary(), binary(), binary()) :: Macro.t()
  defmacro template(action, subject, text, html) do
    quoted_subject = EEx.compile_string(subject)
    quoted_text = EEx.compile_string(text)
    quoted_html = EEx.compile_string(html, engine: Phoenix.HTML.Engine, line: 1, trim: true)

    quote do
      def unquote(action)(var!(assigns)) do
        struct!(unquote(__MODULE__),
          subject: unquote(quoted_subject),
          text: unquote(quoted_text),
          html: unquote(quoted_html)
        )
      end

      def subject(unquote(action)), do: unquote(subject)
      def text(unquote(action)), do: unquote(text)
      def html(unquote(action)), do: unquote(html)
    end
  end
end
