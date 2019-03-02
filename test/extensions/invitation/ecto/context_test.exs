defmodule PowInvitation.Ecto.ContextTest do
  use Pow.Test.Ecto.TestCase
  doctest PowInvitation.Ecto.Context

  alias PowInvitation.Ecto.Context
  alias PowInvitation.Test.{RepoMock, Users.User}

  @config [repo: RepoMock, user: User]

  describe "get_by_invitation_token/2" do
    test "gets when :invitation_accepted_at is nil" do
      assert Context.get_by_invitation_token("valid", @config)
    end

    test "nil when :invitation_accepted_at is not nil" do
      refute Context.get_by_invitation_token("valid_but_accepted", @config)
    end
  end
end
