defmodule PowEmailConfirmation.Ecto.Context do
  @moduledoc false
  use Pow.Extension.Ecto.Context.Base

  alias Pow.Config
  alias Pow.Ecto.Context

  @doc """
  Finds a user by the `email_confirmation_token` column.
  """
  @spec get_by_confirmation_token(Config.t(), binary()) :: map() | nil
  def get_by_confirmation_token(config, token),
    do: Context.get_by(config, email_confirmation_token: token)

  @doc """
  Updates `email_confirmed_at` if it hasn't already been set.
  """
  @spec confirm_email(Config.t(), map()) :: {:ok, map()} | {:error, Changeset.t()}
  def confirm_email(config, user) do
    repo = repo(config)

    case user.email_confirmed_at do
      nil ->
        user
        |> Ecto.Changeset.change(email_confirmed_at: DateTime.utc_now())
        |> repo.update()

      _email_confirmed_at ->
        {:ok, user}
    end
  end
end
