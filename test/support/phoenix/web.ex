defmodule Authex.Test.Phoenix.Web do
  @moduledoc false

  def view do
    quote do
      use Phoenix.View,
        root: "test/support/phoenix/templates",
        namespace: Authex.Test.Phoenix

      alias Authex.Test.Router.Helpers, as: Routes
    end
  end
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
