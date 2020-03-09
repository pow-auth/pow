defmodule PowResetPassword.Ecto.Schema do
  @moduledoc false
  use Pow.Extension.Ecto.Schema.Base

  alias Ecto.Changeset
  alias Pow.Extension.Ecto.Schema

  @impl true
  def validate!(_config, module) do
    Schema.require_schema_field!(module, :email, PowResetPassword)
  end

  @doc false
  @impl true
  defmacro __using__(_config) do
    quote do
      def reset_password_changeset(changeset, attrs), do: pow_reset_password_changeset(changeset, attrs)

      defdelegate pow_reset_password_changeset(changeset, attrs), to: unquote(__MODULE__), as: :reset_password_changeset

      defoverridable reset_password_changeset: 2
    end
  end

  @spec reset_password_changeset(map(), map()) :: Changeset.t()
  def reset_password_changeset(%user_mod{} = user, params) do
    user
    |> user_mod.pow_password_changeset(params)
    |> Changeset.validate_required([:password])
  end
end
