defmodule PowResetPassword.Test.RepoMock do
  @moduledoc false
  alias PowResetPassword.Test.Users.User

  def get_by(User, [email: "test@example.com"]), do: %User{id: 1}
  def get_by(User, [email: "invalid@example.com"]), do: nil

  def update(%{valid?: true}), do: {:ok, %User{id: 1}}
  def update(%{valid?: false} = changeset), do: {:error, %{changeset | action: :update}}
end
