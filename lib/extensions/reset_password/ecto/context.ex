defmodule PowResetPassword.Ecto.Context do
  @moduledoc false
  use Pow.Extension.Ecto.Context.Base

  alias Ecto.Changeset
  alias Pow.Config
  alias Pow.Ecto.Context

  @spec get_by_email(Config.t(), binary()) :: map() | nil
  def get_by_email(config, email), do: Context.get_by(config, email: email)

  @spec update_password(Config.t(), map(), map()) :: {:ok, map()} | {:error, Changeset.t()}
  def update_password(config, user, params) do
    repo = repo(config)

    user
    |> Pow.Ecto.Schema.Changeset.password_changeset(params, config)
    |> repo.update()
  end
end
