defmodule Pow.Extension.Ecto.Context.Base do
  # TODO: Remove by 1.1.0
  @moduledoc false
  alias Pow.Ecto.Context

  @doc false
  defmacro __using__(_opts) do
    quote do
      IO.warn("use #{unquote(__MODULE__)} is deprecated, please use functions in #{Context} instead")

      defdelegate user_schema_mod(config), to: Context
      defdelegate repo(config), to: Context
    end
  end
end
