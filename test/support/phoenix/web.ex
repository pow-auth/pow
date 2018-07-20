defmodule Pow.Test.Phoenix.Web do
  @moduledoc false

  def view do
    quote do
      use Phoenix.View,
        root: "test/support/phoenix/templates",
        namespace: Pow.Test.Phoenix
    end
  end

  def context_app_view do
    quote do
      use Phoenix.View,
        root: "test/support/phoenix/context_app/templates",
        namespace: Pow.Test.Phoenix.Pow
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
