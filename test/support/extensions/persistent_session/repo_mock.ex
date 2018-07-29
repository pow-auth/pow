defmodule PowPersistentSession.Test.RepoMock do
  @moduledoc false
  alias PowPersistentSession.Test.Users.User

  def get_by(User, id: 1), do: %User{id: 1}
  def get_by(User, id: -1), do: nil
  def get_by(User, email: "test@example.com"), do: %User{id: 1, password_hash: Comeonin.Pbkdf2.hashpwsalt("secret1234")}
end
