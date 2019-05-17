defmodule PowEmailConfirmation.Ecto.Context do
  @moduledoc false
  alias Pow.{Config, Ecto.Context}
  alias PowEmailConfirmation.Ecto.Schema

  @doc """
  Finds a user by the `email_confirmation_token` column.
  """
  @spec get_by_confirmation_token(binary(), Config.t()) :: Context.user() | nil
  def get_by_confirmation_token(token, config),
    do: Context.get_by([email_confirmation_token: token], config)

  @doc """
  Updates `email_confirmed_at` if it hasn't already been set.
  """
  @spec confirm_email(Context.user(), Config.t()) :: {:ok, Context.user()} | {:error, Context.changeset()}
  def confirm_email(user, config) do
    user
    |> Schema.confirm_email_changeset()
    |> Context.do_update(config)
  end
end
