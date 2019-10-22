defmodule Pow.Store.CredentialsCache do
  @moduledoc """
  Default module for credentials session storage.

  A key (session id), is used to store, fetch or delete credentials. When
  credentials are stored or deleted, a credentials key will be generated.
  The value of that key will be all current keys (session ids), and the
  most recent credentials.

  When a key is updated, all expired keys will be pruned from the credentials
  key.

  The credentials are expected to take the form of
  `{credentials, session_metadata}`, where session metadata is data exclusive
  to the session id.
  """
  alias Pow.{Config, Store.Base}

  use Base,
    ttl: :timer.minutes(30),
    namespace: "credentials"

  @doc """
  List all user for a certain user struct.

  Sessions for a user can be looked up with `sessions/3`.
  """
  @spec users(Config.t(), module()) :: [any()]
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
  @spec sessions(Config.t(), map()) :: [binary()]
  def sessions(config, user), do: fetch_sessions(config, backend_config(config), user)

  # TODO: Refactor by 1.1.0
  defp fetch_sessions(config, backend_config, user) do
    {struct, id} = user_to_struct_id(user)

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
  @impl true
  def put(config, session_id, {user, metadata}) do
    {struct, id} = user_to_struct_id(user)
    user_key     = [struct, :user, id]
    session_key  = [struct, :user, id, :session, session_id]
    records      = [
      {session_id, {user_key, metadata}},
      {user_key, user},
      {session_key, :os.system_time(:millisecond)}
    ]

    delete_user_sessions_with_fingerprint(config, user, metadata)

    Base.put(config, backend_config(config), records)
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
  @spec get(Config.t(), binary()) :: {map(), list()} | :not_found
  def get(config, session_id) do
    backend_config = backend_config(config)

    with {user_key, metadata} when is_list(user_key) <- Base.get(config, backend_config, session_id),
         user when is_map(user)                      <- Base.get(config, backend_config, user_key) do
      {user, metadata}
    else
      # TODO: Remove by 1.1.0
      {user, metadata} when is_map(user) -> {user, metadata}
      :not_found -> :not_found
    end
  end

  defp user_to_struct_id(%struct{} = user) do
    key_value = case function_exported?(struct, :__schema__, 1) do
      true  -> key_value_from_primary_keys(user)
      false -> primary_keys_to_keyword_list!([:id], user)
    end

    {struct, key_value}
  end
  defp user_to_struct_id(_user), do: raise "Only structs can be stored as credentials"

  defp key_value_from_primary_keys(%struct{} = user) do
    :primary_key
    |> struct.__schema__()
    |> Enum.sort()
    |> primary_keys_to_keyword_list!(user)
  end

  defp primary_keys_to_keyword_list!([], %struct{}), do: raise "No primary keys found for #{inspect struct}"
  defp primary_keys_to_keyword_list!([key], user), do: get_primary_key_value!(user, key)
  defp primary_keys_to_keyword_list!(keys, user) do
    Enum.map(keys, &{&1, get_primary_key_value!(user, &1)})
  end

  defp get_primary_key_value!(%struct{} = user, key) do
    case Map.get(user, key) do
      nil -> raise "Primary key value for key `#{inspect key}` in #{inspect struct} can't be `nil`"
      val -> val
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
