defmodule Pow.Phoenix.Template do
  @moduledoc """
  Module that can builds templates for Phoenix views using EEx with
  `Phoenix.HTML.Engine`.

  ## Example

      defmodule MyApp.ResourceTemplate do
        use Pow.Phoenix.Template

        template :new, :html, "<%= content_tag(:span, "Template") %>"
      end

      MyApp.ResourceTemplate.render("new.html", assigns)
  """

  @doc false
  defmacro __using__(_opts) do
    quote do
      import unquote(__MODULE__)

      import Pow.Phoenix.HTML.ErrorHelpers, only: [error_tag: 2]
      import Phoenix.HTML.{Form, Link}

      alias Pow.Phoenix.Router.Helpers, as: Routes
    end
  end

  @doc """
  Generates template functions.

  This macro that will compile a phoenix view template from the provided
  binary, and add the compiled version to a `render/2` function. The `html/1`
  function outputs the binary.
  """
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
