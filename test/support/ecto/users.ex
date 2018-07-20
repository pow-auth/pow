defmodule Pow.Test.Ecto.Users do
  @moduledoc false
  alias Pow.Ecto.Context
  alias Pow.Test.Ecto.{Repo, Users.User}

  use Context,
    repo: Repo,
    user: User

  def authenticate(:test_macro), do: :ok
  def authenticate(params), do: pow_authenticate(params)

  def create(:test_macro), do: :ok
  def create(params), do: pow_create(params)

  def update(_user, :test_macro), do: :ok
  def update(user, params), do: pow_update(user, params)

  def delete(:test_macro), do: :ok
  def delete(user), do: pow_delete(user)

  def get_by(:test_macro), do: :ok
  def get_by(clauses), do: pow_get_by(clauses)
end
