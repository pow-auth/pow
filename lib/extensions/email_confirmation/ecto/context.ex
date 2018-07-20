defmodule PowEmailConfirmation.Ecto.Context do
  @moduledoc false
  use Pow.Extension.Ecto.Context.Base

  alias Pow.Config
  alias Pow.Ecto.Context

  @spec get_by_confirmation_token(Config.t(), binary()) :: map() | nil
  def get_by_confirmation_token(config, token),
    do: Context.get_by(config, email_confirmation_token: token)

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
