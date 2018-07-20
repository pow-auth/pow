defmodule Pow.Ecto.Schema.Changeset do
  @moduledoc """
  Handles changeset for pow user.
  """
  alias Ecto.Changeset
  alias Pow.{Config, Ecto.Schema}

  @spec changeset(Config.t(), Ecto.Schema.t() | Changeset.t(), map()) :: Changeset.t()
  def changeset(config, user_or_changeset, params) do
    user_or_changeset
    |> login_field_changeset(params, config)
    |> current_password_changeset(params, config)
    |> password_changeset(params, config)
  end

  @spec login_field_changeset(Ecto.Schema.t() | Changeset.t(), map(), Config.t()) :: Changeset.t()
  def login_field_changeset(changeset, params, config) do
    login_field = Schema.login_field(config)

    changeset
    |> Changeset.cast(params, [login_field])
    |> Changeset.update_change(login_field, &Schema.normalize_login_field_value/1)
    |> maybe_validate_email_format(login_field)
    |> Changeset.validate_required([login_field])
    |> Changeset.unique_constraint(login_field)
  end

  @spec password_changeset(Ecto.Schema.t() | Changeset.t(), map(), Config.t()) :: Changeset.t()
  def password_changeset(changeset, params, config) do
    changeset
    |> Changeset.cast(params, [:password, :confirm_password])
    |> maybe_require_password()
    |> maybe_validate_confirm_password()
    |> maybe_put_password_hash(config)
    |> Changeset.validate_required([:password_hash])
  end

  @spec current_password_changeset(Ecto.Schema.t() | Changeset.t(), map(), Config.t()) :: Changeset.t()
  def current_password_changeset(changeset, params, config) do
    changeset
    |> Changeset.cast(params, [:current_password])
    |> maybe_validate_current_password(config)
  end

  defp maybe_validate_email_format(changeset, :email) do
    Changeset.validate_format(changeset, :email, email_regexp())
  end
  defp maybe_validate_email_format(changeset, _), do: changeset

  defp maybe_validate_current_password(%{data: %{password_hash: nil}} = changeset, _config),
    do: changeset
  defp maybe_validate_current_password(changeset, config) do
    changeset = Changeset.validate_required(changeset, [:current_password])

    case changeset.valid? do
      true  -> validate_current_password(changeset, config)
      false -> changeset
    end
  end

  defp validate_current_password(%{data: user, changes: %{current_password: password}} = changeset, config) do
    user
    |> verify_password(password, config)
    |> case do
      true -> changeset
      _    -> Changeset.add_error(changeset, :current_password, "is invalid")
    end
  end

  @spec verify_password(Ecto.Schema.t(), binary(), Config.t()) :: boolean()
  def verify_password(%{password_hash: password_hash}, password, config) do
    config
    |> password_verify_method()
    |> apply([password, password_hash])
  end

  defp maybe_require_password(%{data: %{password_hash: nil}} = changeset) do
    Changeset.validate_required(changeset, [:password])
  end
  defp maybe_require_password(changeset), do: changeset

  defp maybe_validate_confirm_password(changeset) do
    changeset
    |> Changeset.get_change(:password)
    |> case do
      nil      -> changeset
      password -> validate_confirm_password(changeset, password)
    end
  end

  defp validate_confirm_password(changeset, password) do
    confirm_password = Changeset.get_change(changeset, :confirm_password)

    case password do
      ^confirm_password -> changeset
      _                 -> Changeset.add_error(changeset, :confirm_password, "not same as password")
    end
  end

  defp maybe_put_password_hash(%Changeset{valid?: true, changes: %{password: password}} = changeset, config) do
    Changeset.put_change(changeset, :password_hash, hash_password(password, config))
  end
  defp maybe_put_password_hash(changeset, _config), do: changeset

  defp hash_password(password, config) do
    config
    |> password_hash_method()
    |> apply([password])
  end

  @spec pbkdf2_hash(binary()) :: binary()
  def pbkdf2_hash(password), do: Comeonin.Pbkdf2.hashpwsalt(password)

  @spec pbkdf2_verify(binary(), binary()) :: boolean()
  def pbkdf2_verify(hash, password), do: Comeonin.Pbkdf2.checkpw(hash, password)

  defp password_hash_method(config) do
    {password_hash_method, _} = password_hash_methods(config)

    password_hash_method
  end

  defp password_verify_method(config) do
    {_, password_verify_method} = password_hash_methods(config)

    password_verify_method
  end

  defp password_hash_methods(config) do
    Config.get(config, :password_hash_methods, {&pbkdf2_hash/1, &pbkdf2_verify/2})
  end

  @rfc_5332_regexp_no_ip ~r<\A[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*@(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\z>
  defp email_regexp, do: @rfc_5332_regexp_no_ip
end
