defmodule Pow.Ecto.Schema.Changeset do
  @moduledoc """
  Handles changesets methods for Pow schema.

  These methods should never be called directly, but instead the methods
  build in macros in `Pow.Ecto.Schema` should be used. This is to ensure
  that only compile time configuration is used.

  ## Configuration options

    * `:password_min_length`   - minimum password length, defaults to 10
    * `:password_max_length`   - maximum password length, defaults to 4096
    * `:password_hash_methods` - the password hash and verify methods to use,
      defaults to:

          {&Pow.Ecto.Schema.Password.pbkdf2_hash/1,
          &Pow.Ecto.Schema.Password.pbkdf2_verify/2}
    * `:email_validator`       - the email validation method, defaults to:


          &Pow.Ecto.Schema.Changeset.validate_email/1

        The method should either return `:ok`, `:error`, or `{:error, reason}`.
  """
  alias Ecto.Changeset
  alias Pow.{Config, Ecto.Schema, Ecto.Schema.Password}

  @password_min_length 10
  @password_max_length 4096

  @doc """
  Validates the user id field.

  The user id field is always required. It will be treated as case insensitive,
  and it's required to be unique. If the user id field is `:email`, the value
  will be validated as an e-mail address too.
  """
  @spec user_id_field_changeset(Ecto.Schema.t() | Changeset.t(), map(), Config.t()) :: Changeset.t()
  def user_id_field_changeset(user_or_changeset, params, config) do
    user_id_field =
      case user_or_changeset do
        %Changeset{data: %struct{}} -> struct.pow_user_id_field()
        %struct{}                   -> struct.pow_user_id_field()
      end

    user_or_changeset
    |> Changeset.cast(params, [user_id_field])
    |> Changeset.update_change(user_id_field, &Schema.normalize_user_id_field_value/1)
    |> maybe_validate_email_format(user_id_field, config)
    |> Changeset.validate_required([user_id_field])
    |> Changeset.unique_constraint(user_id_field)
  end

  @doc """
  Validates the password field.

  Calls `confirm_password_changeset/3` and `new_password_changeset/3`.
  """
  @spec password_changeset(Ecto.Schema.t() | Changeset.t(), map(), Config.t()) :: Changeset.t()
  def password_changeset(user_or_changeset, params, config) do
    user_or_changeset
    |> confirm_password_changeset(params, config)
    |> new_password_changeset(params, config)
  end

  @doc """
  Validates the password field.

  A password hash is generated by using `:password_hash_methods` in the
  configuration. The password is always required if the password hash is nil,
  and it's required to be between `:password_min_length` to
  `:password_max_length` characters long.

  The password hash is only generated if the changeset is valid, but always
  required.
  """
  @spec new_password_changeset(Ecto.Schema.t() | Changeset.t(), map(), Config.t()) :: Changeset.t()
  def new_password_changeset(user_or_changeset, params, config) do
    user_or_changeset
    |> Changeset.cast(params, [:password])
    |> maybe_require_password()
    |> maybe_validate_password(config)
    |> maybe_put_password_hash(config)
    |> Changeset.validate_required([:password_hash])
  end

  @doc """
  Validates the confirm password field.

  Requires `password` and `confirm_password` params to be equal.
  """
  @spec confirm_password_changeset(Ecto.Schema.t() | Changeset.t(), map(), Config.t()) :: Changeset.t()
  def confirm_password_changeset(user_or_changeset, params, _config) do
    user_or_changeset
    |> Changeset.cast(params, [:password, :confirm_password])
    |> maybe_validate_confirm_password()
  end

  @doc """
  Validates the current password field.

  It's only required to provide a current password if the `password_hash`
  value exists in the data struct.
  """
  @spec current_password_changeset(Ecto.Schema.t() | Changeset.t(), map(), Config.t()) :: Changeset.t()
  def current_password_changeset(user_or_changeset, params, config) do
    user_or_changeset
    |> reset_current_password_field()
    |> Changeset.cast(params, [:current_password])
    |> maybe_validate_current_password(config)
  end

  defp reset_current_password_field(%{data: user} = changeset) do
    %{changeset | data: reset_current_password_field(user)}
  end
  defp reset_current_password_field(user) do
    %{user | current_password: nil}
  end

  defp maybe_validate_email_format(changeset, :email, config) do
    validate_method = email_validator(config)

    Changeset.validate_change(changeset, :email, fn :email, email ->
      case validate_method.(email) do
        :ok              -> []
        :error           -> [email: {"has invalid format", validator: validate_method}]
        {:error, reason} -> [email: {"has invalid format", validator: validate_method, reason: reason}]
      end
    end)
  end
  defp maybe_validate_email_format(changeset, _type, _config), do: changeset

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

  @doc """
  Verifies a password in a struct.

  The password will be verified by using the `:password_hash_methods` in the
  configuration.

  To prevent timing attacks, a blank password will be passed to the hash method
  in the `:password_hash_methods` configuration option if the `:password_hash`
  is nil.
  """
  @spec verify_password(Ecto.Schema.t(), binary(), Config.t()) :: boolean()
  def verify_password(%{password_hash: nil}, _password, config) do
    config
    |> password_hash_method()
    |> apply([""])

    false
  end
  def verify_password(%{password_hash: password_hash}, password, config) do
    config
    |> password_verify_method()
    |> apply([password, password_hash])
  end

  defp maybe_require_password(%{data: %{password_hash: nil}} = changeset) do
    Changeset.validate_required(changeset, [:password])
  end
  defp maybe_require_password(changeset), do: changeset

  defp maybe_validate_password(changeset, config) do
    validate_method = password_validator(config)

    changeset
    |> Changeset.get_change(:password)
    |> case do
      nil -> changeset
      _   -> validate_method.(changeset, config)
    end
  end

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

  defp password_hash_method(config) do
    {password_hash_method, _} = password_hash_methods(config)

    password_hash_method
  end

  defp password_verify_method(config) do
    {_, password_verify_method} = password_hash_methods(config)

    password_verify_method
  end

  defp password_hash_methods(config) do
    Config.get(config, :password_hash_methods, {&Password.pbkdf2_hash/1, &Password.pbkdf2_verify/2})
  end

  defp email_validator(config) do
    Config.get(config, :email_validator, &__MODULE__.validate_email/1)
  end

  defp password_validator(config) do
    Config.get(config, :password_validator, &__MODULE__.validate_password/2)
  end

  @doc """
  Validates a password.

  This implementation only requires that the password is required to be between
  be between `:password_min_length` to `:password_max_length` characters long.
  """
  @spec validate_password(Ecto.Schema.t() | Changeset.t(), Config.t()) :: Changeset.t()
  def validate_password(changeset, config) do
    password_min_length = Config.get(config, :password_min_length, @password_min_length)
    password_max_length = Config.get(config, :password_max_length, @password_max_length)

    Changeset.validate_length(changeset, :password, min: password_min_length, max: password_max_length)
  end

  @doc """
  Validates an e-mail.

  This implementation has the following rules:

  - Split into local-part and domain at last `@` occurance
  - Local-part should;
    - be at most 64 octets
    - separate quoted and unquoted content with a single dot
    - only have letters, digits, and the following characters outside quoted
      content:
        ```text
        !#$%&'*+-/=?^_`{|}~.
        ```
    - not have any consecutive dots outside quoted content
  - Domain should;
    - be at most 255 octets
    - only have letters, digits, hyphen, and dots

  Unicode characters are permitted in both local-part and domain.
  """
  @spec validate_email(binary()) :: :ok | {:error, any()}
  def validate_email(email) do
    [domain | rest] =
      email
      |> String.split("@")
      |> Enum.reverse()

    local_part =
      rest
      |> Enum.reverse()
      |> Enum.join("@")

    cond do
      String.length(local_part) > 64 -> {:error, "local-part too long"}
      String.length(domain) > 255    -> {:error, "domain too long"}
      local_part == ""               -> {:error, "invalid format"}
      true                           -> validate_email(local_part, domain)
    end
  end

  defp validate_email(local_part, domain) do
    sanitized_local_part = remove_quotes_from_local_part(local_part)

    cond do
      local_part_only_quoted?(local_part) ->
        validate_domain(domain)

      local_part_consective_dots?(sanitized_local_part) ->
        {:error, "consective dots in local-part"}

      local_part_valid_characters?(sanitized_local_part) ->
        validate_domain(domain)

      true ->
        {:error, "invalid characters in local-part"}
    end
  end

  defp remove_quotes_from_local_part(local_part),
    do: Regex.replace(~r/(^\".*\"$)|(^\".*\"\.)|(\.\".*\"$)?/, local_part, "")

  defp local_part_only_quoted?(local_part), do: local_part =~ ~r/^"[^\"]+"$/

  defp local_part_consective_dots?(local_part), do: local_part =~ ~r/\.\./

  defp local_part_valid_characters?(sanitized_local_part),
    do: sanitized_local_part =~ ~r<^[\p{L}0-9!#$%&'*+-/=?^_`{|}~\.]+$>u

  defp validate_domain(domain) do
    cond do
      String.first(domain) == "-"     -> {:error, "domain begins with hyphen"}
      String.last(domain) == "-"      -> {:error, "domain ends with hyphen"}
      domain =~ ~r/^[\p{L}0-9-\.]+$/u -> :ok
      true                            -> {:error, "invalid characters in domain"}
    end
  end
end
