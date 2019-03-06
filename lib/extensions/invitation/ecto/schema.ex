defmodule PowInvitation.Ecto.Schema do
  @moduledoc false
  use Pow.Extension.Ecto.Schema.Base
  alias Ecto.Changeset
  alias Pow.UUID

  @impl true
  def attrs(_config) do
    [
      {:invitation_token, :string},
      {:invitation_accepted_at, :utc_datetime}
    ]
  end

  @impl true
  def assocs(_config) do
    [
      {:belongs_to, :invited_by, :users},
      {:has_many, :invited_users, :users, foreign_key: :invited_by_id}
    ]
  end

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
