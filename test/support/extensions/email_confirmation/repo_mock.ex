defmodule PowEmailConfirmation.Test.RepoMock do
  @moduledoc false
  alias Pow.Ecto.Schema.Password
  alias PowEmailConfirmation.Test.Users.User

  @user %User{
    id: 1,
    email: "test@example.com",
    email_confirmation_token: "valid",
    password_hash: Password.pbkdf2_hash("secret1234")
  }

  def one(query, _opts \\ %{}) do
    case inspect(query) =~ "from u0 in PowEmailConfirmation.Test.Users.User, where: u0.email == ^\"taken@example.com\"" do
      true  -> @user
      false -> false
    end
  end

  def get_by(schema, params, opts \\ %{})
  def get_by(User, [email: "test@example.com"], opts) do
    get_by(User, [email_confirmation_token: "valid"], opts)
  end
  def get_by(User, [email: "confirmed@example.com"], opts) do
    get_by(User, [email_confirmation_token: "valid_confirmed"], opts)
  end
  def get_by(User, [email_confirmation_token: "valid"], _opts),
    do: Ecto.put_meta(@user, state: :loaded)
  def get_by(User, [email_confirmation_token: "invalid"], _opts),
    do: nil
  def get_by(User, [email_confirmation_token: "valid_confirmed"], opts) do
    %{get_by(User, [email_confirmation_token: "valid"], opts) | email_confirmed_at: DateTime.utc_now()}
  end
  def get_by(User, [email_confirmation_token: "valid_unconfirmed_email"], opts) do
    user = get_by(User, [email_confirmation_token: "valid_confirmed"], opts)

    %{user | unconfirmed_email: "new@example.com"}
  end

  def update(changeset, opts \\ %{})
  def update(%{changes: %{email: "taken@example.com"}} = changeset, _opts) do
    changeset = Ecto.Changeset.add_error(changeset, :email, "has already been taken")

    {:error, changeset}
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

  def insert(%{valid?: true} = changeset, _opts \\ %{}) do
    token = Ecto.Changeset.get_field(changeset, :email_confirmation_token)
    email = Ecto.Changeset.get_field(changeset, :email)
    user  = %{@user | email_confirmation_token: token, email: email}

    Process.put({:user, user.id}, user)

    {:ok, user}
  end

  def get!(User, 1, _opts \\ %{}), do: Process.get({:user, 1})

  defmodule Invitation do
    @moduledoc false
    alias PowEmailConfirmation.PowInvitation.Test.Users.User
    alias PowEmailConfirmation.Test.RepoMock

    def get_by(User, [invitation_token: "token"], _opts \\ %{}), do: Ecto.put_meta(%User{id: 1, email: "test@example.com"}, state: :loaded)

    def update(changeset, _opts \\ %{}), do: RepoMock.update(changeset)

    def get!(User, 1, _opts \\ %{}), do: Process.get({:user, 1})
  end
end
