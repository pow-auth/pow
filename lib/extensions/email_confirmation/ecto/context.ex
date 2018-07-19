defmodule AuthexEmailConfirmation.Ecto.Context do
  use Authex.Extension.Ecto.Context.Base

  alias Authex.Config

  @spec get_by_confirmation_token(Config.t(), binary()) :: map() | nil
  def get_by_confirmation_token(config, token) do
    user_mod = user_schema_mod(config)
    repo     = repo(config)

    repo.get_by(user_mod, email_confirmation_token: token)
  end

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
