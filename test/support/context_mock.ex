defmodule Pow.Test.ContextMock do
  @moduledoc false
  alias Pow.Test.Ecto.Users.User
  use Pow.Ecto.Context

  @valid_params %{"email" => "test@example.com", "password" => "secret"}
  @user %User{id: 1, email: "test@example.com", password_hash: ""}

  def authenticate(@valid_params), do: @user
  def authenticate(_params), do: nil

  def create(@valid_params), do: {:ok, @user}
  def create(params), do: {:error, %{User.changeset(%User{}, params) | action: :insert}}

  def update(%{id: 1}, @valid_params), do: {:ok, %{@user | id: :updated}}
  def update(user, params), do: {:error, %{User.changeset(user, params) | action: :update}}

  def delete(%{id: 1}), do: {:ok, %{@user | id: :deleted}}
  def delete(_user), do: {:error, %{User.changeset(%User{}, %{}) | action: :delete}}

  defmodule UsernameUser do
    @moduledoc false

    alias Pow.Test.Ecto.Users.UsernameUser

    def create(_any), do: {:ok, %UsernameUser{id: 1, username: "test"}}
  end
end
