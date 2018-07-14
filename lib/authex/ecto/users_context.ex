defmodule Authex.Ecto.UsersContext do
  @moduledoc """
  Handles authex users context for user.

  ## Usage

  This module will be used by authex by default. If you
  wish to have control over context methods, you can
  do configure `lib/my_project/user/users.ex`
  the following way:

      defmodule MyProject.Users do
        use Authex.Ecto.UsersContext,
          repo: MyApp.Repo,
          user: MyProject.Users.User,
          password_hash_methods: {&Authex.Ecto.UserContext.pbkdf2_hash/1,
                                  &Authex.Ecto.UserContext.pbkdf2_verify/2}

        def changeset(user_or_changeset, config, params) do
          user_or_changeset
          |> authex_changeset(config, params)
          |> Ecto.Changeset.cast(params, [:name])
          |> Ecto.Changeset.validate_required([:name])
        end
      end

  Remember to update configuration with `users_context: MyProject.Users`.

  The following Authex methods can be accessed:
    - `authex_changeset/3`
    - `authex_authenticate/2`
    - `authex_create/2`
    - `authex_update/3`
    - `authex_delete/2`
  """

  alias Authex.Ecto.{Schema, UsersContext.Behaviour}
  alias Authex.Config
  alias Ecto.Changeset

  @behaviour Behaviour
  @type user :: map()

  defmacro __using__(config) do
    quote do
      @behaviour Behaviour

      def changeset(user_or_changeset, config, params),
        do: authex_changeset(user_or_changeset, config, params)

      def authex_changeset(user_or_changeset, config, params) do
        config = authex_update_config(config)
        unquote(__MODULE__).changeset(user_or_changeset, config, params)
      end

      def authenticate(config, params),
        do: authex_authenticate(config, params)

      def authex_authenticate(config, params) do
        config
        |> authex_update_config()
        |> unquote(__MODULE__).authenticate(params)
      end

      def create(config, params),
        do: authex_create(config, params)

      def authex_create(config, params) do
        config
        |> authex_update_config()
        |> unquote(__MODULE__).create(params, &changeset/3)
      end

      def update(config, user, params),
        do: authex_update(config, user, params)

      def authex_update(config, user, params) do
        config
        |> authex_update_config()
        |> unquote(__MODULE__).update(user, params, &changeset/3)
      end

      def delete(config, user),
        do: authex_delete(config, user)

      def authex_delete(config, user) do
        config
        |> authex_update_config()
        |> unquote(__MODULE__).delete(user)
      end

      defp authex_update_config(config),
        do: Keyword.merge(config, unquote(config))

      defoverridable Behaviour
    end
  end

  @spec changeset(Config.t(), map()) :: Changeset.t()
  def changeset(config, params) do
    config
    |> user_schema_mod()
    |> struct()
    |> changeset(config, params)
  end
  @spec changeset(user() | Changeset.t(), Config.t(), map()) :: Changeset.t()
  def changeset(user_or_changeset, config, params) do
    login_field =
      config
      |> user_schema_mod()
      |> Schema.login_field()

    user_or_changeset
    |> Changeset.cast(params, [login_field, :current_password, :password, :password_confirm])
    |> maybe_validate_current_password(config)
    |> maybe_require_password()
    |> maybe_validate_password_confirm()
    |> maybe_put_password_hash(config)
    |> Changeset.validate_required([login_field, :password_hash])
    |> Changeset.unique_constraint(login_field)
  end

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
    |> verify_password(config, password)
    |> case do
      true -> changeset
      _    -> Changeset.add_error(changeset, :current_password, "is invalid")
    end
  end

  defp maybe_require_password(%{data: %{password_hash: nil}} = changeset) do
    Changeset.validate_required(changeset, [:password])
  end
  defp maybe_require_password(changeset), do: changeset

  defp maybe_validate_password_confirm(changeset) do
    changeset
    |> Changeset.get_change(:password)
    |> case do
      nil      -> changeset
      password -> validate_password_confirm(changeset, password)
    end
  end

  defp validate_password_confirm(changeset, password) do
    password_confirm = Changeset.get_change(changeset, :password_confirm)

    case password do
      ^password_confirm -> changeset
      _                 -> Changeset.add_error(changeset, :password_confirm, "not same as password")
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

  @spec authenticate(Config.t(), map()) :: user() | nil
  def authenticate(config, params) do
    user        = user_schema_mod(config)
    login_field = Schema.login_field(user)
    login_value = params[Atom.to_string(login_field)]
    password    = params["password"]

    config
    |> get_by_login_field(user, login_field, login_value)
    |> maybe_verify_password(config, password)
  end

  defp get_by_login_field(_config, _user, _login_field, nil), do: nil
  defp get_by_login_field(config, user, login_field, login_value) do
    repo(config).get_by(user, [{login_field, login_value}])
  end

  defp maybe_verify_password(nil, _config, _password),
    do: nil
  defp maybe_verify_password(user, config, password) do
    case verify_password(user, config, password) do
      true -> user
      _    -> nil
    end
  end

  defp verify_password(%{password_hash: password_hash}, config, password) do
    config
    |> password_verify_method()
    |> apply([password, password_hash])
  end

  @spec create(Config.t(), map()) :: {:ok, user()} | {:error, Changeset.t()}
  def create(config, params, changeset_method \\ &changeset/3) do
    config
    |> user_schema_mod()
    |> struct()
    |> changeset_method.(config, params)
    |> repo(config).insert()
  end

  @spec update(Config.t(), user(), map()) :: {:ok, user()} | {:error, Changeset.t()}
  def update(config, user, params, changeset_method \\ &changeset/3) do
    user
    |> changeset_method.(config, params)
    |> repo(config).update()
  end

  @spec delete(Config.t(), user()) :: {:ok, user()} | {:error, Changeset.t()}
  def delete(config, user) do
    repo(config).delete(user)
  end

  @spec pbkdf2_hash(binary()) :: binary()
  def pbkdf2_hash(password), do: Comeonin.Pbkdf2.hashpwsalt(password)

  @spec pbkdf2_verify(binary(), binary()) :: boolean()
  def pbkdf2_verify(hash, password), do: Comeonin.Pbkdf2.checkpw(hash, password)

  defp repo(config) do
    Config.get(config, :repo, nil) || raise_no_repo_error()
  end

  defp user_schema_mod(config) do
    Config.get(config, :user, nil) || raise_no_user_error()
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
    Config.get(config, :password_hash_methods, {&pbkdf2_hash/1, &pbkdf2_verify/2})
  end

  @spec raise_no_repo_error() :: no_return
  defp raise_no_repo_error() do
    Config.raise_error("No :repo configuration option found for users context module.")
  end

  @spec raise_no_user_error() :: no_return
  defp raise_no_user_error() do
    Config.raise_error("No :user configuration option found for user schema module.")
  end
end
