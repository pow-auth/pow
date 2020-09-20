defmodule PowEmailConfirmation.Test.RepoMock do
  @moduledoc false
  alias Pow.Ecto.Schema.Password
  alias PowEmailConfirmation.Test.Users.User

  @password_hash Password.pbkdf2_hash("secret1234")

  defp user() do
    Ecto.put_meta(%User{
      id: 1,
      email: "test@example.com",
      password_hash: @password_hash,
      email_confirmation_token: "valid"
    }, state: :loaded)
  end

  def get_by(User, [id: 1], _opts), do: Process.get({:user, 1})
  def get_by(User, [email: "test@example.com"], _opts), do: user()
  def get_by(User, [email: "with-unconfirmed-changed-email@example.com"], _opts) do
    %{user() | unconfirmed_email: "new@example.com", email_confirmed_at: DateTime.utc_now()}
  end
  def get_by(User, [email: "confirmed-email@example.com"], _opts) do
    %{user() | email_confirmed_at: DateTime.utc_now(), email_confirmation_token: nil}
  end
  def get_by(User, [email_confirmation_token: "valid"], _opts), do: user()
  def get_by(User, [email_confirmation_token: "invalid"], _opts), do: nil
  def get_by(User, [email_confirmation_token: "valid-with-unconfirmed-changed-email"], _opts) do
    %{user() | unconfirmed_email: "new@example.com", email_confirmed_at: DateTime.utc_now()}
  end
  def get_by(User, [email_confirmation_token: "valid-with-taken-email"], _opts) do
    %{user() | unconfirmed_email: "taken@example.com", email_confirmed_at: DateTime.utc_now()}
  end

  def update(%{changes: %{email: "taken@example.com"}, valid?: true} = changeset, _opts) do
    changeset = Ecto.Changeset.add_error(changeset, :email, "has already been taken", constraint: :unique, constraint_name: "users_email_index")

    {:error, %{changeset | action: :update}}
  end
  def update(%{valid?: true} = changeset, _opts) do
    %{changeset | repo: __MODULE__}
    |> run_prepare()
    |> do_update()
  end

  defp do_update(%{valid?: true} = changeset) do
    user = Ecto.Changeset.apply_changes(changeset)
    Process.put({:user, user.id}, user)

    {:ok, user}
  end
  defp do_update(changeset), do: {:error, changeset}

  defp run_prepare(%{prepare: prepare} = changeset) do
    prepare
    |> Enum.reverse()
    |> Enum.reduce(changeset, & &1.(&2))
  end

  def insert(%{valid?: false} = changeset, _opts), do: {:error, %{changeset | action: :insert}}
  def insert(%{changes: %{email: "taken@example.com"}, valid?: true} = changeset, _opts) do
    changeset = Ecto.Changeset.add_error(changeset, :email, "has already been taken", constraint: :unique, constraint_name: "users_email_index")

    {:error, %{changeset | action: :insert}}
  end
  def insert(%{valid?: true} = changeset, _opts) do
    user =
      changeset
      |> Ecto.Changeset.apply_changes()
      |> Map.put(:id, 1)
      |> Ecto.put_meta(state: :loaded)

    Process.put({:user, user.id}, user)

    {:ok, user}
  end

  defmodule Invitation do
    @moduledoc false
    alias PowEmailConfirmation.PowInvitation.Test.Users.User
    alias PowEmailConfirmation.Test.RepoMock

    def get_by(User, [id: 1], _opts), do: Process.get({:user, 1})
    def get_by(User, [invitation_token: "token"], _opts), do: Ecto.put_meta(%User{id: 1, email: "test@example.com"}, state: :loaded)

    def update(changeset, opts), do: RepoMock.update(changeset, opts)
  end
end
