defmodule PowResetPassword.Ecto.Context do
  @moduledoc false
  use Pow.Extension.Ecto.Context.Base

  alias Ecto.Changeset
  alias Pow.Config
  alias Pow.Ecto.Context

  @spec get_by_email(binary(), Config.t()) :: map() | nil
  def get_by_email(email, config), do: Context.get_by([email: email], config)

  @spec update_password(map(), map(), Config.t()) :: {:ok, map()} | {:error, Changeset.t()}
  def update_password(user, params, config) do
    user
    |> user.__struct__.pow_password_changeset(params)
    |> Changeset.validate_required([:password])
    |> Context.do_update(config)
  end
end
