defmodule Authex.Phoenix.Template do
  @moduledoc """
  Module that can builds templates for Phoenix views using
  EEx with Phoenix.HTML.Engine.

  Example:

    defmodule MyApp.ResourceTemplate do
      use Authex.Phoenix.Template

      template :new, :html, "<%= content_tag(:span, "Template") %>"

      template :edit, :html, {:form, [{:text, :custom}]}
    end

    MyApp.ResourceTemplate.render("new.html", assigns)
  """
  defmacro __using__(_opts) do
    quote do
      import unquote(__MODULE__)
    end
  end

  @spec template(atom(), atom(), binary() | {atom(), any()}) :: Macro.t()
  defmacro template(action, :html, content) do
    content = EEx.eval_string(content)
    render_html_template(action, content)
  end

  defp render_html_template(action, content) do
    quoted = EEx.compile_string(content, engine: Phoenix.HTML.Engine, line: 1, trim: true)

    quote do
      def render(unquote("#{action}.html"), var!(assigns)) do
        _ = var!(assigns)
        unquote(quoted)
      end

      def html(unquote(action)), do: unquote(content)
    end
  end
end
