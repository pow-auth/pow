defmodule Pow.Phoenix.Mailer.View do
  defmacro __using__(_opts) do
    quote do
      @template_module Pow.Phoenix.View.__template_module__(__MODULE__)

      def render(action, assigns) do
        @template_module.render(action, assigns)
      end

      def subject(action), do: @template_module.subject(action)
    end
  end
end
