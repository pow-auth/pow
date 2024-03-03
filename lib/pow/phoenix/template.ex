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
      import unquote(__MODULE__)

      unquote do
        # Credo will complain about unless statement but we want this first
        # credo:disable-for-next-line
        unless Pow.dependency_vsn_match?(:phoenix, "< 1.7.0") do
          quote do
            use Phoenix.Component
            import Pow.Phoenix.HTML.CoreComponents
            alias Phoenix.LiveView.JS
          end
        else
          # TODO: Remove when Phoenix 1.7 is required
          quote do
            import Pow.Phoenix.HTML.ErrorHelpers, only: [error_tag: 2]
            import Phoenix.HTML.{Form, Link}
          end
        end
      end

      # TODO: Remove when Phoenix 1.7 is required
      unquote do
        if Code.ensure_loaded?(Phoenix.View) do
          quote do
            @after_compile {unquote(__MODULE__), :__after_compile_phoenix_view__}
          end
        end
      end

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
    content = "<% import #{__MODULE__}, only: [__inline_route__: 2, __user_id_field__: 2] %>#{content}"

    content =
      # Credo will complain about unless statement but we want this first
      # credo:disable-for-next-line
      unless Pow.dependency_vsn_match?(:phoenix, "< 1.7.0") do
        content
      else
        # TODO: Remove when Phoenix 1.7 required
        "<% import #{Pow.Phoenix.HTML.FormTemplate}, only: [render_form: 1, render_form: 2] %>#{content}"
      end

    content =
      # TODO: Remove when Phoenix 1.7 required and fallback templates removed
      # Credo will complain about unless statement but we want this first
      # credo:disable-for-next-line
      unless Pow.dependency_vsn_match?(:phoenix, "< 1.7.0") do
        String.replace(content, "<%= render_form", "<%% render_form")
      else
        content
      end

    expr =
      EEx.eval_string(
        content,
        [],
        file: __CALLER__.file,
        line: __CALLER__.line + 1,
        caller: __CALLER__)

    opts =
      # Credo will complain about unless statement but we want this first
      # credo:disable-for-next-line
      unless Pow.dependency_vsn_match?(:phoenix, "< 1.7.0") do
        [
          engine: Phoenix.LiveView.TagEngine,
          file: __CALLER__.file,
          line: __CALLER__.line + 1,
          caller: %{__CALLER__ | function: {:template, 3}},
          source: expr,
          tag_handler: Phoenix.LiveView.HTMLEngine]
      else
        # TODO: Remove when Phoenix 1.7 required
        [
          engine: Phoenix.HTML.Engine,
          file: __CALLER__.file,
          line: __CALLER__.line + 1,
          caller: __CALLER__,
          source: expr]
      end

    quoted = EEx.compile_string(expr, opts)

    quote do
      def unquote(action)(var!(assigns)) do
        _ = var!(assigns)
        unquote(quoted)
      end

      def html(unquote(action)), do: unquote(expr)
    end
  end

  @doc false
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

  @doc false
  def __user_id_field__(type, :key) do
    "Pow.Ecto.Schema.user_id_field(#{type})"
  end
  def __user_id_field__(type, :type) do
    "Pow.Ecto.Schema.user_id_field(#{type}) == :email && \"email\" || \"text\""
  end
  def __user_id_field__(type, :label) do
    "Phoenix.Naming.humanize(Pow.Ecto.Schema.user_id_field(#{type}))"
  end
end
