defmodule Pow.Store.CredentialsCache do
  @moduledoc """
  Default module for credentials session storage.

  A key (session id) is used to store, fetch, or delete credentials. The
  credentials are expected to take the form of
  `{credentials, session_metadata}`, where session metadata is data exclusive
  to the session id.

  This module also adds two utility functions:

    * `users/2` - to list all current users
    * `sessions/2` - to list all current sessions

  The `:ttl` should be maximum 30 minutes per
  [OWASP recommendations](https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html#session-expiration).
  A warning will be output for any sessions created with a longer TTL.

  ## Custom credentials cache module

  Pow may use the utility functions in this module. To ensure all required
  functions has been implemented in a custom credentials cache module, the
  `@behaviour` of this module should be used:

      defmodule MyApp.CredentialsStore do
        use Pow.Store.Base,
          ttl: :timer.minutes(30),
          namespace: "credentials"

        @behaviour Pow.Store.CredentialsCache

        @impl Pow.Store.CredentialsCache
        def users(config, struct) do
          # ...
        end

        @impl Pow.Store.CredentialsCache
        def put(config, key, value) do
          # ...
        end
      end

  ## Configuration options

    * `:reload` - boolean value for whether the user object should be loaded
      from the context. Defaults false.

  """
  alias Pow.{Config, Operations, Store.Base}

  @callback users(Base.config(), module()) :: [any()]
  @callback sessions(Base.config(), map()) :: [binary()]
  @callback put(Base.config(), binary(), {map(), list()}) :: :ok

  # Per https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html#session-expiration
  @recommended_max_idle_timeout :timer.minutes(30)

  use Base,
    ttl: :timer.minutes(30),
    namespace: "credentials"

  @doc """
  List all user for a certain user struct.

  Sessions for a user can be looked up with `sessions/3`.
  """
  @spec users(Base.config(), module()) :: [any()]
  def users(config, struct) do
    config
    |> Base.all(backend_config(config), [struct, :user, :_])
    |> Enum.map(fn {[^struct, :user, _id], user} ->
      user
    end)
  end

  @doc """
  List all existing sessions for the user fetched from the backend store.
  """
  @spec sessions(Base.config(), map()) :: [binary()]
  def sessions(config, user), do: fetch_sessions(config, backend_config(config), user)

  # TODO: Refactor by 1.1.0
  defp fetch_sessions(config, backend_config, user) do
    {struct, id} = user_to_struct_id!(user, [])

    config
    |> Base.all(backend_config, [struct, :user, id, :session, :_])
    |> Enum.map(fn {[^struct, :user, ^id, :session, session_id], _value} ->
      session_id
    end)
  end

  @doc """
  Add user credentials with the session id to the backend store.

  The credentials are expected to be in the format of
  `{credentials, metadata}`.

  This following three key-value will be inserted:

    - `{session_id, {[user_struct, :user, user_id], metadata}}`
    - `{[user_struct, :user, user_id], user}`
    - `{[user_struct, :user, user_id, :session, session_id], inserted_at}`

  If metadata has `:fingerprint` any active sessions for the user with the same
  `:fingerprint` in metadata will be deleted.
  """
  @spec put(Base.config(), binary(), {map(), list()}) :: :ok
  def put(config, session_id, {user, metadata}) do
    {struct, id} = user_to_struct_id!(user, [])
    user_key     = [struct, :user, id]
    session_key  = [struct, :user, id, :session, session_id]
    records      = [
      {session_id, {user_key, metadata}},
      {user_key, user},
      {session_key, :os.system_time(:millisecond)}
    ]

    delete_user_sessions_with_fingerprint(config, user, metadata)

    backend_config =
      config
      |> backend_config()
      |> warn_maximum_timeout()

    Base.put(config, backend_config, records)
  end

  defp warn_maximum_timeout(config) do
    if Config.get(config, :ttl, 0) > @recommended_max_idle_timeout do
      IO.warn(
        """
        warning: `:ttl` value for sessions should be no longer than #{round(@recommended_max_idle_timeout / 1_000 / 60)} minutes to prevent session hijack, please consider lowering the value
        """)
    end

    config
  end

  @doc """
  Delete the user credentials data from the backend store.

  This following two key-value will be deleted:

  - `{session_id, {[user_struct, :user, user_id], metadata}}`
  - `{[user_struct, :user, user_id, :session, session_id], inserted_at}`

  The `{[user_struct, :user, user_id], user}` key-value is expected to expire
  when reaching its TTL.
  """
  @impl true
  def delete(config, session_id) do
    backend_config = backend_config(config)

    case Base.get(config, backend_config, session_id) do
      {[struct, :user, key_id], _metadata} ->
        session_key = [struct, :user, key_id, :session, session_id]

        Base.delete(config, backend_config, session_id)
        Base.delete(config, backend_config, session_key)

      # TODO: Remove by 1.1.0
      {user, _metadata} when is_map(user) ->
        Base.delete(config, backend_config, session_id)

      :not_found ->
        :ok
    end
  end

  @doc """
  Fetch user credentials from the backend store from session id.
  """
  @impl true
  @spec get(Base.config(), binary()) :: {map(), list()} | nil | :not_found
  def get(config, session_id) do
    backend_config = backend_config(config)

    with {user_key, metadata} when is_list(user_key) <- Base.get(config, backend_config, session_id),
         user when is_map(user)                      <- Base.get(config, backend_config, user_key),
         user when not is_nil(user)                  <- maybe_reload(user, config) do
      {user, metadata}
    else
      # TODO: Remove by 1.1.0
      {user, metadata} when is_map(user) -> {user, metadata}
      :not_found -> :not_found
      nil -> nil
    end
  end

  defp maybe_reload(user, config) do
    # TODO: By 1.1.0 set this to `true` and update docs
    case Keyword.get(config, :reload, false) do
      true -> Operations.reload(user, fetch_pow_config!(config))
      _any -> user
    end
  end

  defp fetch_pow_config!(config), do: Keyword.get(config, :pow_config) || raise "No `:pow_config` value found in the store config."

  defp user_to_struct_id!(%mod{} = user, config) do
    key_values =
      user
      |> fetch_primary_key_values!(config)
      |> Enum.sort(&elem(&1, 0) < elem(&2, 0))
      |> case do
        [id: id] -> id
        clauses  -> clauses
      end

    {mod, key_values}
  end
  defp user_to_struct_id!(_user, _config), do: raise "Only structs can be stored as credentials"

  defp fetch_primary_key_values!(user, config) do
    pow_config = Keyword.get(config, :pow_config)

    user
    |> Operations.fetch_primary_key_values(pow_config)
    |> case do
      {:error, error} -> raise error
      {:ok, clauses}  -> clauses
    end
  end

  defp delete_user_sessions_with_fingerprint(config, user, metadata) do
    case Keyword.get(metadata, :fingerprint) do
      nil         -> :ok
      fingerprint -> do_delete_user_sessions_with_fingerprint(config, user, fingerprint)
    end
  end

  defp do_delete_user_sessions_with_fingerprint(config, user, fingerprint) do
    backend_config = backend_config(config)

    config
    |> sessions(user)
    |> Enum.each(fn session_id ->
      with {_user_key, metadata} when is_list(metadata) <- Base.get(config, backend_config, session_id),
           ^fingerprint <- Keyword.get(metadata, :fingerprint) do
        delete(config, session_id)
      end
    end)
  end

  # TODO: Remove by 1.1.0
  @doc false
  @deprecated "Use `users/2` or `sessions/2` instead"
  def user_session_keys(config, backend_config, struct) do
    config
    |> Base.all(backend_config, [struct, :user, :_, :session, :_])
    |> Enum.map(fn {key, _value} ->
      key
    end)
  end

  # TODO: Remove by 1.1.0
  @doc false
  @deprecated "Use `sessions/2` instead"
  def sessions(config, backend_config, user), do: fetch_sessions(config, backend_config, user)
end
