defmodule Pow.Phoenix.Mailer.Component do
  @moduledoc """
  Compnent macros for `Pow.Phoenix.Mailer`.

  ## Usage

      defmodule MyAppWeb.Web do
        @moduledoc false
        use Pow.Phoenix.Mailer.Component

        @html ~H\"""
        <p>Hi, <% @user %>, this is <i>HTML</i>!</p>
        ""\"

        @text ~P\"""
        Hi, <%= @user %>, this is plain text!
        ""\"
      end
  """
  defmacro __using__(_opts) do
    quote do
      import unquote(__MODULE__)
    end
  end

  defmacro sigil_H({:<<>>, meta, [expr]}, []) do
    unless Macro.Env.has_var?(__CALLER__, {:assigns, nil}) do
      raise "~H requires a variable named \"assigns\" to exist and be set to a map"
    end

    options = [
      engine: Phoenix.HTML.Engine,
      file: __CALLER__.file,
      line: __CALLER__.line + 1,
      caller: __CALLER__,
      indentation: meta[:indentation] || 0,
      source: expr
    ]

    EEx.compile_string(expr, options)
  end

  defmacro sigil_P({:<<>>, meta, [expr]}, []) do
    unless Macro.Env.has_var?(__CALLER__, {:assigns, nil}) do
      raise "~P requires a variable named \"assigns\" to exist and be set to a map"
    end

    options = [
      file: __CALLER__.file,
      line: __CALLER__.line + 1,
      caller: __CALLER__,
      indentation: meta[:indentation] || 0,
      source: expr
    ]

    EEx.compile_string(expr, options)
  end
end
