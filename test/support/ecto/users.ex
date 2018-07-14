defmodule Authex.Test.Ecto.Users do
  alias Authex.Ecto.Context
  alias Authex.Test.Ecto.{Repo, Users.User}

  use Context,
    repo: Repo,
    user: User

  def authenticate(:test_macro), do: :ok
  def authenticate(params), do: authex_authenticate(params)

  def create(:test_macro), do: :ok
  def create(params), do: authex_create(params)

  def update(_user, :test_macro), do: :ok
  def update(user, params), do: authex_update(user, params)

  def delete(:test_macro), do: :ok
  def delete(user), do: authex_delete(user)
end
