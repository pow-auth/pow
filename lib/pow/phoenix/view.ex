defmodule Pow.Phoenix.View do
  @moduledoc """
  View macros for Pow Phoenix, that calls render functions generated with
  `Pow.Phoenix.Template`.

  ## Usage

      defmodule MyExtension.Phoenix.CustomView do
        @moduledoc false
        use Pow.Phoenix.View
      end
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
  def __template_module__(view_module) do
    [view_module | context] =
      view_module
      |> Module.split()
      |> Enum.reverse()

    template_module =
      view_module
      |> String.trim_trailing("View")
      |> Kernel.<>("Template")

    context
    |> Enum.reverse()
    |> Enum.concat([template_module])
    |> Module.concat()
  end
end
