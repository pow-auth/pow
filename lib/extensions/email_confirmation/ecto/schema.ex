defmodule PowEmailConfirmation.Ecto.Schema do
  @moduledoc false
  use Pow.Extension.Ecto.Schema.Base
  alias Ecto.Changeset
  alias Pow.{Extension.Ecto.Schema, UUID}

  def validate!(_config, module) do
    Schema.require_schema_field!(module, :email, PowEmailConfirmation)
  end

  def attrs(_config) do
    [
      {:email_confirmation_token, :string},
      {:email_confirmed_at, :utc_datetime},
      {:unconfirmed_email, :string}
    ]
  end

  def indexes(_config) do
    [{:email_confirmation_token, true}]
  end

  def changeset(%{errors: []} = changeset, _attrs, _config) do
    current_email = changeset.data.email
    new_email     = Changeset.get_field(changeset, :email)
    state         = Ecto.get_meta(changeset.data, :state)

    changeset
    |> maybe_put_email_confirmation_token(state, current_email, new_email)
    |> maybe_set_unconfirmed_email(state, current_email, new_email)
  end
  def changeset(changeset, _attrs, _config), do: changeset

  @spec confirm_email_changeset(Ecto.Schema.t() | Changeset.t()) :: Changeset.t()
  def confirm_email_changeset(user_or_changeset) do
    user_or_changeset
    |> Changeset.change()
    |> maybe_confirm_email()
  end

  defp maybe_confirm_email(%{data: %{unconfirmed_email: unconfirmed_email}} = changeset) when not is_nil(unconfirmed_email) do
    confirm_email(changeset)
  end
  defp maybe_confirm_email(%{data: %{email_confirmed_at: confirmed_at}} = changeset) when is_nil(confirmed_at) do
    confirm_email(changeset)
  end
  defp maybe_confirm_email(changeset), do: changeset

  defp confirm_email(changeset) do
    changes   = [
      email_confirmed_at: DateTime.truncate(DateTime.utc_now(), :second),
      email: changeset.data.unconfirmed_email || changeset.data.email,
      unconfirmed_email: nil]

    changeset
    |> Changeset.change(changes)
    |> Changeset.validate_required([:email, :email_confirmed_at])
    |> Changeset.unique_constraint(:email)
  end

  defp maybe_put_email_confirmation_token(changeset, state, current_email, new_email) when current_email != new_email or state == :built do
    changeset
    |> Changeset.put_change(:email_confirmation_token, UUID.generate())
    |> Changeset.validate_required([:email_confirmation_token])
    |> Changeset.unique_constraint(:email_confirmation_token)
  end
  defp maybe_put_email_confirmation_token(changeset, _state, _current_email, _new_email), do: changeset

  defp maybe_set_unconfirmed_email(changeset, :loaded, current_email, new_email) when current_email != new_email do
    changeset
    |> Changeset.put_change(:email, current_email)
    |> Changeset.put_change(:unconfirmed_email, new_email)
  end
  defp maybe_set_unconfirmed_email(changeset, _state, _current_email, _new_email), do: changeset
end
