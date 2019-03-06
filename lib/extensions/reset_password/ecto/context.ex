defmodule PowResetPassword.Ecto.Context do
  @moduledoc false
  use Pow.Extension.Ecto.Context.Base

  alias Ecto.Changeset
  alias Pow.{Config, Ecto.Context}
  alias PowResetPassword.Ecto.Schema

  @spec get_by_email(binary(), Config.t()) :: map() | nil
  def get_by_email(email, config), do: Context.get_by([email: email], config)

  @spec update_password(map(), map(), Config.t()) :: {:ok, map()} | {:error, Changeset.t()}
  def update_password(user, params, config) do
    user
    |> Schema.reset_password_changeset(params)
    |> Context.do_update(config)
  end

  # TODO: Remove by 1.1.0
  @deprecated "Use `PowResetPassword.Ecto.Schema.reset_password_changeset/2` instead"
  def password_changeset(user, params), do: Schema.reset_password_changeset(user, params)
end
