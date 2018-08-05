defmodule Pow.Phoenix.View do
  @moduledoc """
  View macros for Pow Phoenix, that calls render methods generated with
  `Pow.Phoenix.Template`.
  """

  @doc false
  defmacro __using__(_opts) do
    quote do
      @template_module unquote(__MODULE__).__template_module__(__MODULE__)

      def render(action, assigns) do
        @template_module.render(action, assigns)
      end
    end
  end

  @doc false
  @spec __template_module__(atom()) :: atom()
  def __template_module__(view_module) do
    [name | rest] =
      view_module
      |> Module.split()
      |> Enum.reverse()

    name =
      name
      |> String.trim_trailing("View")
      |> Kernel.<>("Template")

    rest
    |> Enum.reverse()
    |> Enum.concat([name])
    |> Module.concat()
  end
end
