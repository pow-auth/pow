defmodule PowEmailConfirmation.Ecto.Schema do
  @moduledoc false
  use Pow.Extension.Ecto.Schema.Base
  alias Ecto.Changeset
  alias Pow.{Config, UUID}

  def validate!(config, user_id_field) do
    case user_id_field do
      :email -> config
      _      -> raise_user_id_field_not_email_error()
    end
  end

  def attrs(_config) do
    [{:email_confirmation_token, :string},
     {:email_confirmed_at, :utc_datetime}]
  end

  def indexes(_config) do
    [{:email_confirmation_token, true}]
  end

  def changeset(changeset, _attrs, _config) do
    changeset
    |> put_email_confirmation_token()
    |> Changeset.validate_required([:email_confirmation_token])
    |> Changeset.unique_constraint(:email_confirmation_token)
  end

  defp put_email_confirmation_token(changeset) do
    current_email = changeset.data.email

    changeset
    |> Changeset.get_field(:email)
    |> case do
      ^current_email -> changeset
      _new_email -> Changeset.put_change(changeset, :email_confirmation_token, UUID.generate())
    end
  end

  @spec raise_user_id_field_not_email_error :: no_return
  defp raise_user_id_field_not_email_error do
    Config.raise_error("The `:user_id_field` has to be `:email` for PowEmailConfirmation to work")
  end
end
