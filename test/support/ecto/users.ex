defmodule Authex.Test.Ecto.Users do
  alias Authex.Ecto.UsersContext
  alias Ecto.Changeset
  alias Authex.Test.Ecto.{Repo, Users.User}

  use UsersContext,
    repo: Repo,
    user: User

  def changeset(user_or_changeset, config, params) do
    user_or_changeset
    |> authex_changeset(config, params)
    |> Changeset.cast(params, [:username])
  end

  def authenticate(_config, :test_macro), do: :ok
  def authenticate(config, params) do
    authex_authenticate(config, params)
  end

  def create(config, params) do
    authex_create(config, params)
  end

  def update(config, user, params) do
    authex_update(config, user, params)
  end

  def delete(_config, :test_macro), do: :ok
  def delete(config, user) do
    authex_delete(config, user)
  end
end
