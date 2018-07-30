defmodule Pow.Phoenix.Mailer.View do
  @moduledoc """
  View macros for `Pow.Phoenix.Mailer` that calls render methods generated with
  `Pow.Phoenix.Mailer.Template`.
  """
  defmacro __using__(_opts) do
    quote do
      @template_module Pow.Phoenix.View.__template_module__(__MODULE__)

      def render(mail, assigns) do
        @template_module.render(mail, assigns)
      end

      def subject(mail, _assigns), do: @template_module.subject(mail)
    end
  end
end
