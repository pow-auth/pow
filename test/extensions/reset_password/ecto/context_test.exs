defmodule PowResetPassword.Ecto.ContextTest do
  use Pow.Test.Ecto.TestCase
  doctest PowResetPassword.Ecto.Context

  alias PowResetPassword.Ecto.Context
  alias PowResetPassword.Test.{RepoMock, Users.User}

  @config [repo: RepoMock, user: User]

  describe "get_by_email/2" do
    test "email is case insensitive when it's a login field" do
      assert Context.get_by_email(@config, "test@example.com")
      assert Context.get_by_email(@config, "TEST@EXAMPLE.COM")
    end
  end
end
