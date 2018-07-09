defmodule Authex.Test.UsersContextMock do
  @valid_params %{"email" => "test@example.com", "password" => "secret"}
  @invalid_params %{"email" => "test@example.com"}

  def authenticate(_config, @valid_params), do: {:ok, %{id: 1}}
  def authenticate(_config, @invalid_params), do: {:error, :invalid_password}
  def authenticate(_config, _params), do: {:error, :not_found}

  def changeset(_config, params), do: params

  def create(_config, @valid_params), do: {:ok, %{id: 1}}
  def create(_config, params), do: {:error, params}

  def update(_config, %{id: 1}, @valid_params), do: {:ok, %{id: 1, updated: true}}
  def update(_config, _user, params), do: {:error, params}

  def delete(_config, %{id: 1}), do: {:ok, %{id: 1}}
  def delete(_config, user), do: {:error, user}
end
