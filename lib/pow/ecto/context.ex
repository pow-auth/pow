defmodule Pow.Ecto.Context do
  @moduledoc """
  Handles pow users context for user.

  ## Usage

  This module will be used by pow by default. If you
  wish to have control over context functions, you can
  do configure `lib/my_project/users/users.ex`
  the following way:

      defmodule MyApp.Users do
        use Pow.Ecto.Context,
          repo: MyApp.Repo,
          user: MyApp.Users.User

        def create(params) do
          pow_create(params)
        end
      end

  Remember to update configuration with `users_context: MyApp.Users`.

  The following Pow functions can be accessed:

    * `pow_authenticate/1`
    * `pow_create/1`
    * `pow_update/2`
    * `pow_delete/1`
    * `pow_get_by/1`

  ## Configuration options

    * `:repo` - the ecto repo module (required)
    * `:user` - the user schema module (required)
    * `:repo_opts` - keyword list options for the repo, `:prefix` can be set here
  """
  alias Pow.{Config, Context, Ecto.Schema, Operations}

  @type user :: Context.user()
  @type changeset :: Context.changeset()

  @doc false
  defmacro __using__(config) do
    quote do
      @behaviour Context

      @pow_config Keyword.put_new(unquote(config), :users_context, __MODULE__)

      def authenticate(params), do: pow_authenticate(params)
      def create(params), do: pow_create(params)
      def update(user, params), do: pow_update(user, params)
      def delete(user), do: pow_delete(user)
      def get_by(clauses), do: pow_get_by(clauses)

      def pow_authenticate(params) do
        unquote(__MODULE__).authenticate(params, @pow_config)
      end

      def pow_create(params) do
        unquote(__MODULE__).create(params, @pow_config)
      end

      def pow_update(user, params) do
        unquote(__MODULE__).update(user, params, @pow_config)
      end

      def pow_delete(user) do
        unquote(__MODULE__).delete(user, @pow_config)
      end

      def pow_get_by(clauses) do
        unquote(__MODULE__).get_by(clauses, @pow_config)
      end

      defoverridable Context
    end
  end

  @doc """
  Finds a user based on the user id, and verifies the password on the user.

  User schema module and repo module will be fetched from the config. The user
  id field is fetched from the user schema module.

  The function will return nil if either the fetched user or password is nil.

  To prevent timing attacks, a blank user struct will be passed to the
  `verify_password/2` function for the user schema module to ensure that the
  the response time will be equal as when a password is verified.
  """
  @spec authenticate(map(), Config.t()) :: user() | nil
  def authenticate(params, config) do
    user_mod      = Config.user!(config)
    user_id_field = user_mod.pow_user_id_field()
    user_id_value = params[Atom.to_string(user_id_field)]
    password      = params["password"]

    do_authenticate(user_id_field, user_id_value, password, config)
  end

  defp do_authenticate(_user_id_field, nil, _password, _config), do: nil
  defp do_authenticate(user_id_field, user_id_value, password, config) do
    [{user_id_field, user_id_value}]
    |> Operations.get_by(config)
    |> verify_password(password, config)
  end

  defp verify_password(nil, _password, config) do
    user_mod = Config.user!(config)
    user     = struct(user_mod, password_hash: nil)
    user_mod.verify_password(user, "")

    nil
  end
  defp verify_password(_user, nil, _config), do: false
  defp verify_password(user, password, _config) do
    case user.__struct__.verify_password(user, password) do
      true -> user
      _    -> nil
    end
  end

  @doc """
  Creates a new user.

  User schema module and repo module will be fetched from config.
  """
  @spec create(map(), Config.t()) :: {:ok, user()} | {:error, changeset()}
  def create(params, config) do
    user_mod = Config.user!(config)

    user_mod
    |> struct()
    |> user_mod.changeset(params)
    |> do_insert(config)
  end

  @doc """
  Updates the user.

  User schema module will be fetched from provided user and repo will be
  fetched from the config.
  """
  @spec update(user(), map(), Config.t()) :: {:ok, user()} | {:error, changeset()}
  def update(user, params, config) do
    user
    |> user.__struct__.changeset(params)
    |> do_update(config)
  end

  @doc """
  Deletes the user.

  Repo module will be fetched from the config.
  """
  @spec delete(user(), Config.t()) :: {:ok, user()} | {:error, changeset()}
  def delete(user, config) do
    opts = repo_opts(config, [:prefix])

    Config.repo!(config).delete(user, opts)
  end

  @doc """
  Retrieves an user by the provided clauses.

  User schema module and repo module will be fetched from the config.
  """
  @spec get_by(Keyword.t() | map(), Config.t()) :: user() | nil
  def get_by(clauses, config) do
    user_mod = Config.user!(config)
    clauses  = normalize_user_id_field_value(user_mod, clauses)
    opts     = repo_opts(config, [:prefix])

    Config.repo!(config).get_by(user_mod, clauses, opts)
  end

  defp normalize_user_id_field_value(user_mod, clauses) do
    user_id_field = user_mod.pow_user_id_field()

    Enum.map(clauses, fn
      {^user_id_field, value} when is_binary(value) -> {user_id_field, Schema.normalize_user_id_field_value(value)}
      any -> any
    end)
  end

  @doc """
  Inserts a changeset to the database.

  If succesful, the returned row will be reloaded from the database.
  """
  @spec do_insert(changeset(), Config.t()) :: {:ok, user()} | {:error, changeset()}
  def do_insert(changeset, config) do
    opts = repo_opts(config, [:prefix])
    repo = Config.repo!(config)

    repo.insert(changeset, opts)
  end

  @doc """
  Updates a changeset in the database.

  If succesful, the returned row will be reloaded from the database.
  """
  @spec do_update(changeset(), Config.t()) :: {:ok, user()} | {:error, changeset()}
  def do_update(changeset, config) do
    opts = repo_opts(config, [:prefix])
    repo = Config.repo!(config)

    repo.update(changeset, opts)
  end

  # TODO: Remove by 1.1.0
  @deprecated "Use `Pow.Config.repo!/1` instead"
  defdelegate repo(config), to: Config, as: :repo!

  defp repo_opts(config, opts) do
    config
    |> Config.get(:repo_opts, [])
    |> Keyword.take(opts)
  end

  # TODO: Remove by 1.1.0
  @deprecated "Use `Pow.Config.user!/1` instead"
  defdelegate user_schema_mod(config), to: Config, as: :user!
end
