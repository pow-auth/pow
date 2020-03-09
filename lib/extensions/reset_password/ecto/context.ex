defmodule PowResetPassword.Ecto.Context do
  @moduledoc false
  alias Pow.{Config, Ecto.Context, Operations}
  alias PowResetPassword.Ecto.Schema

  @spec get_by_email(binary(), Config.t()) :: Context.user() | nil
  def get_by_email(email, config), do: Operations.get_by([email: email], config)

  @spec update_password(Context.user(), map(), Config.t()) :: {:ok, Context.user()} | {:error, Context.changeset()}
  def update_password(%user_mod{} = user, params, config) do
    user
    |> user_mod.reset_password_changeset(params)
    |> Context.do_update(config)
  end

  # TODO: Remove by 1.1.0
  @deprecated "Use `PowResetPassword.Ecto.Schema.reset_password_changeset/2` instead"
  def password_changeset(user, params), do: Schema.reset_password_changeset(user, params)
end
