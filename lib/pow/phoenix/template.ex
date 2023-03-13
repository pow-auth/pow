defmodule Pow.Phoenix.Template do
  @moduledoc """
  Module that can builds templates for Phoenix using EEx with
  `Phoenix.HTML.Engine`.

  ## Example

      defmodule MyApp.ResourceTemplate do
        use Pow.Phoenix.Template

        template :new, :html, "<%= content_tag(:span, "Template") %>"
      end

      MyApp.ResourceTemplate.new(assigns)
  """

  @doc false
  defmacro __using__(_opts) do
    quote do
      @after_compile {unquote(__MODULE__), :__after_compile_phoenix_view__}

      import unquote(__MODULE__)

      import Pow.Phoenix.HTML.ErrorHelpers, only: [error_tag: 2]
      import Phoenix.HTML.{Form, Link}

      unquote do
        # TODO: Remove when Phoenix 1.7 is required
        unless Code.ensure_loaded?(Phoenix.VerifiedRoutes) do
          quote do
            alias Pow.Phoenix.Router.Helpers, as: Routes
          end
        end
      end
    end
  end

  # TODO: Remove when Phoenix 1.7 is required
  @doc false
  def __after_compile_phoenix_view__(env, _bytecode) do
    if Code.ensure_loaded?(Phoenix.View) do
      view_module =
        env.module
        |> Phoenix.Naming.unsuffix("HTML")
        |> Kernel.<>("View")
        |> String.to_atom()

      Module.create(
        view_module,
        for {name, 1} <- env.module.__info__(:functions) do
          quote do
            def render(unquote("#{name}.html"), assigns) do
              apply(unquote(env.module), unquote(name), [assigns])
            end
          end
        end,
        Macro.Env.location(__ENV__))
    end
  end

  @doc """
  Generates HTML template functions.

  This macro that will compile a phoenix template from the provided binary, and
  add the compiled version to a `:action/2` function. The `html/1` function
  outputs the binary.
  """
  @spec template(atom(), atom(), binary() | {atom(), any()}) :: Macro.t()
  defmacro template(action, :html, content) do
    content = EEx.eval_string(content)
    render_html_template(action, content)
  end

  defp render_html_template(action, content) do
    quoted = EEx.compile_string(content, engine: Phoenix.HTML.Engine, line: 1, trim: true)

    quote do
      def unquote(action)(var!(assigns)) do
        _ = var!(assigns)
        unquote(quoted)
      end

      def html(unquote(action)), do: unquote(content)
    end
  end

  if Code.ensure_loaded?(Phoenix.VerifiedRoutes) do
    def __inline_route__(plug, plug_opts) do
      "Pow.Phoenix.Routes.path_for(@conn, #{inspect plug}, #{inspect plug_opts})"
    end
  else
    # TODO: Remove when Phoenix 1.7 is required
    def __inline_route__(plug, plug_opts) do
      "Routes.#{Pow.Phoenix.Controller.route_helper(plug)}_path(@conn, #{inspect plug_opts}) %>"
    end
  end
end
