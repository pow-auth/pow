defmodule PowResetPassword.Ecto.Context do
  use Pow.Extension.Ecto.Context.Base

  alias Pow.Config
  alias Ecto.Changeset

  @spec get_by_email(Config.t(), binary()) :: map() | nil
  def get_by_email(config, email) do
    user_mod = user_schema_mod(config)
    repo     = repo(config)

    repo.get_by(user_mod, email: email)
  end

  @spec update_password(Config.t(), map(), map()) :: {:ok, map()} | {:error, Changeset.t()}
  def update_password(config, user, params) do
    repo = repo(config)

    user
    |> Pow.Ecto.Schema.Changeset.password_changeset(params, config)
    |> repo.update()
  end
end
