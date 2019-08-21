defmodule PowInvitation.Ecto.Schema do
  @moduledoc """
  Handles the invitation schema for user.
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
  defmacro __using__(_config) do
    quote do
      def invite_changeset(changeset, invited_by, attrs), do: pow_invite_changeset(changeset, invited_by, attrs)

      defdelegate pow_invite_changeset(changeset, invited_by, attrs), to: unquote(__MODULE__), as: :invite_changeset

      defoverridable invite_changeset: 3
    end
  end

  @doc """
  Invites user.

  It's important to note that this changeset should not include the changeset
  method in the user schema module if `PowEmailConfirmation` has been enabled.
  This is because the e-mail is assumed confirmed already if the user can
  accept the invitation.

  A unique `:invitation_token` will be generated, and `invited_by` association
  will be set. Only the user id will be set, and the persisted user won't have
  any password for authentication.
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

  defp invitation_token_changeset(changeset) do
    changeset
    |> Changeset.put_change(:invitation_token, UUID.generate())
    |> Changeset.unique_constraint(:invitation_token)
  end

  defp invited_by_changeset(%Changeset{data: data} = changeset, invited_by) do
    data = Ecto.build_assoc(invited_by, :invited_users, data)

    Changeset.assoc_constraint(%{changeset | data: data}, :invited_by)
  end

  @doc """
  Accepts an invitation.

  The changeset method in user schema module is called, and
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
