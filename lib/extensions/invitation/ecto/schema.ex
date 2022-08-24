defmodule PowInvitation.Ecto.Schema do
  @moduledoc """
  Handles the invitation schema for user.

  ## Customize PowInvitation associations or fields

  If you need to modify any of the associations or fields that `PowInvitation`
  adds to the user schema, you can override them by defining them before
  `pow_user_fields/0`:

      defmodule MyApp.Users.User do
        use Ecto.Schema
        use Pow.Ecto.Schema
        use Pow.Extension.Ecto.Schema,
          extensions: [PowInvitation]

        schema "users" do
          belongs_to :invited_by, __MODULE__
          has_many :invited_users __MODULE__, foreign_key: :invited_by_id, on_delete: delete_all

          field :invitation_token, :string
          field :invitation_accepted_at, :utc_datetime

          pow_user_fields()

          timestamps()
        end
      end

  ## Customize PowInvitation changeset

  You can extract individual changeset functions to modify the changeset flow
  entirely. As an example, this is how you can invite a user through email
  while using `username` as the user id field:

      defmodule MyApp.Users.User do
        use Ecto.Schema
        use Pow.Ecto.Schema,
          user_id_field: :username

        import PowInvitation.Ecto.Schema,
          only: [invitation_token_changeset: 1, invited_by_changeset: 2]

        # ...

        def invite_changeset(user_or_changeset, invited_by, attrs) do
          user_or_changeset
          |> cast(attrs, [:email])
          |> validate_required([:email])
          |> invitation_token_changeset()
          |> invited_by_changeset(invited_by)
        end
      end
  """

  use Pow.Extension.Ecto.Schema.Base
  alias Ecto.Changeset
  alias Pow.UUID

  @doc false
  @impl true
  def attrs(_config) do
    [
      {:invitation_token, :string},
      {:invitation_accepted_at, :utc_datetime}
    ]
  end

  @doc false
  @impl true
  def assocs(_config) do
    [
      {:belongs_to, :invited_by, :users},
      {:has_many, :invited_users, :users, foreign_key: :invited_by_id}
    ]
  end

  @doc false
  @impl true
  def indexes(_config) do
    [{:invitation_token, true}]
  end

  @doc false
  @impl true
  defmacro __using__(_config) do
    quote do
      def invite_changeset(changeset, invited_by, attrs), do: pow_invite_changeset(changeset, invited_by, attrs)

      defdelegate pow_invite_changeset(changeset, invited_by, attrs), to: unquote(__MODULE__), as: :invite_changeset

      def accept_invitation_changeset(changeset, attrs), do: pow_accept_invitation_changeset(changeset, attrs)

      defdelegate pow_accept_invitation_changeset(changeset, attrs), to: unquote(__MODULE__), as: :accept_invitation_changeset

      defoverridable invite_changeset: 3, accept_invitation_changeset: 2
    end
  end

  @doc """
  Invites user.

  It's important to note that this changeset should not include the changeset
  function in the user schema module if `PowEmailConfirmation` has been
  enabled. This is because the e-mail is assumed confirmed already if the user
  can accept the invitation.

  A unique `:invitation_token` will be generated, and `invited_by` association
  will be set. Only the user id will be set, and the persisted user won't have
  any password for authentication.

  Calls `invitation_token_changeset/1` and `invited_by_changeset/2`.
  """
  @spec invite_changeset(Ecto.Schema.t() | Changeset.t(), Ecto.Schema.t(), map()) :: Changeset.t()
  def invite_changeset(%Changeset{data: user} = changeset, invited_by, attrs) do
    changeset
    |> user.__struct__.pow_user_id_field_changeset(attrs)
    |> invitation_token_changeset()
    |> invited_by_changeset(invited_by)
  end
  def invite_changeset(user, invited_by, attrs) do
    user
    |> Changeset.change()
    |> invite_changeset(invited_by, attrs)
  end

  @doc """
  Sets the invitation token.
  """
  @spec invitation_token_changeset(Ecto.Schema.t() | Changeset.t()) :: Changeset.t()
  def invitation_token_changeset(changeset) do
    changeset
    |> Changeset.change(%{invitation_token: UUID.generate()})
    |> Changeset.unique_constraint(:invitation_token)
  end

  @doc """
  Sets the invited by association.
  """
  @spec invited_by_changeset(Ecto.Schema.t() | Changeset.t(), Ecto.Schema.t()) :: Changeset.t()
  def invited_by_changeset(%Changeset{data: data} = changeset, invited_by) do
    data = Ecto.build_assoc(invited_by, :invited_users, data)

    Changeset.assoc_constraint(%{changeset | data: data}, :invited_by)
  end
  def invited_by_changeset(user, invited_by) do
    user
    |> Changeset.change()
    |> invited_by_changeset(invited_by)
  end

  @doc """
  Accepts an invitation.

  The changeset function in user schema module is called, and
  `:invitation_accepted_at` will be updated. The password can be set, and the
  user id updated.
  """
  @spec accept_invitation_changeset(Ecto.Schema.t() | Changeset.t(), map()) :: Changeset.t()
  def accept_invitation_changeset(%Changeset{data: %user_mod{}} = changeset, attrs) do
    accepted_at = Pow.Ecto.Schema.__timestamp_for__(user_mod, :invitation_accepted_at)

    changeset
    |> user_mod.changeset(attrs)
    |> Changeset.change(invitation_accepted_at: accepted_at)
  end
  def accept_invitation_changeset(user, attrs) do
    user
    |> Changeset.change()
    |> accept_invitation_changeset(attrs)
  end
end
