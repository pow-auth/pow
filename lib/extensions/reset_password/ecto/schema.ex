defmodule PowResetPassword.Ecto.Schema do
  @moduledoc false
  use Pow.Extension.Ecto.Schema.Base

  alias Ecto.Changeset
  alias Pow.Extension.Ecto.Schema

  @impl true
  def validate!(_config, module) do
    Schema.require_schema_field!(module, :email, PowResetPassword)
  end

  @spec reset_password_changeset(map(), map()) :: Changeset.t()
  def reset_password_changeset(%user_mod{} = user, params) do
    user
    |> user_mod.pow_password_changeset(params)
    |> Changeset.validate_required([:password])
  end
end
