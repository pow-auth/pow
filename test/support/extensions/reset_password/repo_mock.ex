defmodule PowResetPassword.Test.RepoMock do
  alias PowResetPassword.Test.Users.User

  def get_by(_mod, [email: "test@example.com"]), do: %User{id: 1}
  def get_by(_mod, _test), do: nil

  def update(%{valid?: true}), do: {:ok, %User{id: 1}}
  def update(changeset), do: {:error, %{changeset | action: :update}}
end
