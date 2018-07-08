defmodule Authex.Test.UserMock do
  def authenticate(%{"email" => "test@example.com", "password" => "secret"}), do: {:ok, %{id: 1}}
  def authenticate(%{"email" => "test@example.com"}), do: {:error, :invalid_password}
  def authenticate(_params), do: {:error, :not_found}
end
