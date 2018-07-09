defmodule Authex.Test.UserMock do
  @valid_params %{"email" => "test@example.com", "password" => "secret"}
  @invalid_params %{"email" => "test@example.com"}

  def authenticate(@valid_params), do: {:ok, %{id: 1}}
  def authenticate(@invalid_params), do: {:error, :invalid_password}
  def authenticate(_params), do: {:error, :not_found}

  def changeset(params), do: params

  def create(@valid_params), do: {:ok, %{id: 1}}
  def create(params), do: {:error, params}

  def update(%{id: 1}, @valid_params), do: {:ok, %{id: 1, updated: true}}
  def update(_user, params), do: {:error, params}

  def delete(%{id: 1}), do: {:ok, %{id: 1}}
  def delete(user), do: {:error, user}
end
