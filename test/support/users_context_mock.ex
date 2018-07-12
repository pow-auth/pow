defmodule Authex.Test.UsersContextMock do
  alias Authex.Test.Ecto.Users

  @valid_params %{"email" => "test@example.com", "password" => "secret"}
  @user %Users.User{id: 1, password_hash: ""}

  def authenticate(_config, @valid_params), do: @user
  def authenticate(_config, _params), do: nil

  def changeset(config, params), do: changeset(%Users.User{}, config, params)
  def changeset(user_or_changeset, config, params) do
    Users.changeset(user_or_changeset, config, params)
  end

  def create(_config, @valid_params), do: {:ok, @user}
  def create(config, params), do: {:error, %{changeset(config, params) | action: :create}}

  def update(_config, %{id: 1}, @valid_params), do: {:ok, %{id: 1, updated: true}}
  def update(config, user, params), do: {:error, %{changeset(user, config, params) | action: :update}}

  def delete(_config, %{id: 1}), do: {:ok, %{id: 1}}
  def delete(config, _user), do: {:error, %{changeset(config, %{}) | action: :delete}}
end
