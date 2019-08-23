defmodule PowEmailConfirmation.Ecto.Context do
  @moduledoc """
  Handles e-mail confirmation context for user.
  """
  alias Pow.{Config, Ecto.Context}
  alias PowEmailConfirmation.Ecto.Schema

  @doc """
  Finds a user by the `email_confirmation_token` column.
  """
  @spec get_by_confirmation_token(binary(), Config.t()) :: Context.user() | nil
  def get_by_confirmation_token(token, config),
    do: Context.get_by([email_confirmation_token: token], config)

  @doc """
  Checks if the users current e-mail is unconfirmed.
  """
  @spec current_email_unconfirmed?(Context.user(), Config.t()) :: boolean()
  def current_email_unconfirmed?(%{unconfirmed_email: nil, email_confirmation_token: token, email_confirmed_at: nil}, _config) when not is_nil(token),
    do: true
  def current_email_unconfirmed?(_user, _config),
    do: false

  @doc """
  Checks if the user has a pending e-mail change.
  """
  @spec pending_email_change?(Context.user(), Config.t()) :: boolean()
  def pending_email_change?(%{unconfirmed_email: email, email_confirmation_token: token}, _config) when not is_nil(email) and not is_nil(token),
    do: true
  def pending_email_change?(_user, _config), do: false

  @doc """
  Confirms e-mail.

  See `PowEmailConfirmation.Ecto.Schema.confirm_email_changeset/1`.
  """
  @spec confirm_email(Context.user(), Config.t()) :: {:ok, Context.user()} | {:error, Context.changeset()}
  def confirm_email(user, config) do
    user
    |> Schema.confirm_email_changeset()
    |> Context.do_update(config)
  end
end
