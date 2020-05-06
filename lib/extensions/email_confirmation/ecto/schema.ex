defmodule PowEmailConfirmation.Ecto.Schema do
  @moduledoc """
  Handles the e-mail confirmation schema for user.

  ## Customize PowEmailConfirmation fields

  If you need to modify any of the fields that `PowEmailConfirmation` adds to
  the user schema, you can override them by defining them before
  `pow_user_fields/0`:

      defmodule MyApp.Users.User do
        use Ecto.Schema
        use Pow.Ecto.Schema
        use Pow.Extension.Ecto.Schema,
          extensions: [PowEmailConfirmation]

        schema "users" do
          field :email_confirmation_token, :string
          field :email_confirmed_at, :utc_datetime
          field :unconfirmed_email, :string

          pow_user_fields()

          timestamps()
        end
      end
  """

  use Pow.Extension.Ecto.Schema.Base
  alias Ecto.Changeset
  alias Pow.{Config, Extension.Ecto.Schema, UUID}

  @doc false
  @impl true
  def validate!(_config, module) do
    Schema.require_schema_field!(module, :email, PowEmailConfirmation)
  end

  @doc false
  @impl true
  def attrs(_config) do
    [
      {:email_confirmation_token, :string},
      {:email_confirmed_at, :utc_datetime},
      {:unconfirmed_email, :string}
    ]
  end

  @doc false
  @impl true
  def indexes(_config) do
    [{:email_confirmation_token, true}]
  end

  @doc false
  @impl true
  defmacro __using__(_config) do
    quote do
      def confirm_email_changeset(changeset, attrs), do: pow_confirm_email_changeset(changeset, attrs)

      defdelegate pow_confirm_email_changeset(changeset, attrs), to: unquote(__MODULE__), as: :confirm_email_changeset

      defoverridable confirm_email_changeset: 2
    end
  end

  @doc """
  Handles e-mail confirmation if e-mail is updated.

  The `:email_confirmation_token` will always be set if the struct isn't
  persisted to the database.

  For structs persisted to the database, no changes will happen if there is no
  `:email` in the params. Likewise, no changes will happen if the `:email`
  change is the same as the persisted `:unconfirmed_email` value.

  If the `:email` change is the same as the persisted `:email` value then both
  `:email_confirmation_token` and `:unconfirmed_email` will be set to nil.

  Otherwise the `:email` change will be copied over to `:unconfirmed_email` and
  the `:email` change will be reverted back to the original persisted `:email`
  value. A unique `:email_confirmation_token` will be generated.
  """
  @impl true
  @spec changeset(Changeset.t(), map(), Config.t()) :: Changeset.t()
  def changeset(%{valid?: true} = changeset, attrs, _config) do
    cond do
      built?(changeset) ->
        put_email_confirmation_token(changeset)

      email_reverted?(changeset, attrs) ->
        changeset
        |> Changeset.put_change(:email_confirmation_token, nil)
        |> Changeset.put_change(:unconfirmed_email, nil)

      email_changed?(changeset) ->
        current_email = changeset.data.email
        changed_email = Changeset.get_field(changeset, :email)
        changeset     = set_unconfirmed_email(changeset, current_email, changed_email)

        case unconfirmed_email_changed?(changeset) do
          true -> put_email_confirmation_token(changeset)
          false -> changeset
        end

      true ->
        changeset
    end
  end
  def changeset(changeset, _attrs, _config), do: changeset

  defp built?(changeset), do: Ecto.get_meta(changeset.data, :state) == :built

  defp email_reverted?(changeset, attrs) do
    param   = Map.get(attrs, :email) || Map.get(attrs, "email")
    current = changeset.data.email

    param == current
  end

  defp email_changed?(changeset) do
    case Changeset.get_change(changeset, :email) do
      nil  -> false
      _any -> true
    end
  end

  defp put_email_confirmation_token(changeset) do
    changeset
    |> Changeset.put_change(:email_confirmation_token, UUID.generate())
    |> Changeset.unique_constraint(:email_confirmation_token)
  end

  defp set_unconfirmed_email(changeset, current_email, new_email) do
    changeset
    |> Changeset.put_change(:email, current_email)
    |> Changeset.put_change(:unconfirmed_email, new_email)
  end

  defp unconfirmed_email_changed?(changeset) do
    case Changeset.get_change(changeset, :unconfirmed_email) do
      nil  -> false
      _any -> true
    end
  end

  @doc """
  Sets the e-mail as confirmed.

  This updates `:email_confirmed_at` and sets `:email_confirmation_token` to
  nil.

  If the struct has a `:unconfirmed_email` value, then the `:email` will be
  changed to this value, and `:unconfirmed_email` will be set to nil.
  """
  @spec confirm_email_changeset(Ecto.Schema.t() | Changeset.t(), map()) :: Changeset.t()
  def confirm_email_changeset(%Changeset{data: %{unconfirmed_email: unconfirmed_email}} = changeset, params) when not is_nil(unconfirmed_email) do
    confirm_email(changeset, unconfirmed_email, params)
  end
  def confirm_email_changeset(%Changeset{data: %{email_confirmed_at: nil, email: email}} = changeset, params) do
    confirm_email(changeset, email, params)
  end
  def confirm_email_changeset(%Changeset{} = changeset, _params), do: changeset
  def confirm_email_changeset(user, params) do
    user
    |> Changeset.change()
    |> confirm_email_changeset(params)
  end

  defp confirm_email(changeset, email, _params) do
    confirmed_at = Pow.Ecto.Schema.__timestamp_for__(changeset.data.__struct__, :email_confirmed_at)
    changes      =
      [
        email_confirmed_at: confirmed_at,
        email: email,
        unconfirmed_email: nil,
        email_confirmation_token: nil
      ]

    changeset
    |> Changeset.change(changes)
    |> Changeset.unique_constraint(:email)
  end

  # TODO: Remove by 1.1.0
  @deprecated "Use `confirm_email_changeset/2` instead"
  @doc false
  def confirm_email_changeset(changeset), do: confirm_email_changeset(changeset, %{})
end
