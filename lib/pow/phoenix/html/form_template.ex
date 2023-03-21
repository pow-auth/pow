# TODO: Remove when Phoenix 1.7.0 is required
unless Pow.dependency_vsn_match?(:phoenix, ">= 1.7.0") do
defmodule Pow.Phoenix.HTML.FormTemplate do
  @moduledoc false
  alias Pow.Phoenix.HTML.{Bootstrap, Minimalist}

  @doc false
  @spec render_form(list(), Keyword.t()) :: Macro.t()
  def render_form(inputs, opts \\ []) do
    opts = Keyword.put_new(opts, :button_label, "Submit")

    case css(opts) do
      # TODO: Remove bootstrap support by 1.1.0 and only support Phoenix 1.4.0
      :bootstrap -> Bootstrap.render_form(inputs, opts)
      :minimalist -> Minimalist.render_form(inputs, opts)
    end
  end

  defp css(opts) do
    default =
      case Keyword.get(opts, :bootstrap, Pow.dependency_vsn_match?(:phoenix, "~> 1.3.0")) do
        true -> :bootstrap
        false -> :minimalist
      end

    Keyword.get(opts, :css, default)
  end
end
end
