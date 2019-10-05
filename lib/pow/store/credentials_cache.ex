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
  List all user session keys stored for a certain user struct.

  Each user session key can be used to look up all sessions for that user.
  """
  @spec user_session_keys(Config.t(), Config.t(), module()) :: [any()]
  def user_session_keys(config, backend_config, struct) do
    namespace = "#{Macro.underscore(struct)}_sessions_"

    config
    |> Base.keys(backend_config)
    |> Enum.filter(&String.starts_with?(&1, namespace))
  end

  @doc """
  List all existing sessions for the user fetched from the backend store.
  """
  @spec sessions(Config.t(), Config.t(), map()) :: [binary()]
  def sessions(config, backend_config, user) do
    case Base.get(config, backend_config, user_session_list_key(user)) do
      :not_found            -> []
      %{sessions: sessions} -> sessions
    end
  end

  @doc """
  Add user credentials with the session id to the backend store.

  This will either create or update the current user credentials in the
  backend store. The session id will be appended to the session list for the
  user credentials.

  The credentials are expected to be in the format of
  `{credentials, metadata}`.
  """
  @impl true
  @spec put(Config.t(), Config.t(), binary(), {map(), list()}) :: :ok
  def put(config, backend_config, session_id, {user, metadata}) do
    key = append_to_session_list(config, backend_config, session_id, user)

    Base.put(config, backend_config, session_id, {key, metadata})
  end

  @doc """
  Delete the sesison id from the backend store.

  This will delete the session id from the session list for the user
  credentials in the backend store. If the session id is the only one in the
  session list, the user credentials will be deleted too from the backend
  store.
  """
  @impl true
  @spec delete(Config.t(), Config.t(), binary()) :: :ok
  def delete(config, backend_config, session_id) do
    case Base.get(config, backend_config, session_id) do
      :not_found ->
        :ok

      {key, _metadata} ->
        Base.delete(config, backend_config, session_id)
        delete_from_session_list(config, backend_config, session_id, key)
    end
  end

  @doc """
  Fetch user credentials from the backend store from session id.
  """
  @impl true
  @spec get(Config.t(), Config.t(), binary()) :: {map(), list()} | :not_found
  def get(config, backend_config, session_id) do
    with {key, metadata} when is_binary(key) <- Base.get(config, backend_config, session_id),
         %{user: user}                       <- Base.get(config, backend_config, key) do
      {user, metadata}
    else
      # TODO: Remove by 1.1.0
      {user, metadata} when is_map(user) -> {user, metadata}
      :not_found -> :not_found
    end
  end

  defp append_to_session_list(config, backend_config, session_id, user) do
    new_list =
      config
      |> sessions(backend_config, user)
      |> Enum.reject(&get(config, backend_config, &1) == :not_found)
      |> Enum.concat([session_id])
      |> Enum.uniq()

    update_session_list(config, backend_config, user, new_list)
  end

  defp delete_from_session_list(config, backend_config, session_id, key) do
    %{user: user} = Base.get(config, backend_config, key)

    config
    |> sessions(backend_config, user)
    |> Enum.filter(&(&1 != session_id))
    |> case do
      []       -> Base.delete(config, backend_config, key)
      new_list -> update_session_list(config, backend_config, user, new_list)
    end
  end

  defp update_session_list(config, backend_config, user, list) do
    key = user_session_list_key(user)

    Base.put(config, backend_config, key, %{user: user, sessions: list})

    key
  end

  defp user_session_list_key(%struct{} = user) do
    key_value =
      case function_exported?(struct, :__schema__, 1) do
        true  -> key_value_from_primary_keys(user)
        false -> primary_keys_to_binary!([:id], user)
      end

    "#{Macro.underscore(struct)}_sessions_#{key_value}"
  end
  defp user_session_list_key(_user), do: raise "Only structs can be stored as credentials"

  defp key_value_from_primary_keys(%struct{} = user) do
    :primary_key
    |> struct.__schema__()
    |> Enum.sort()
    |> primary_keys_to_binary!(user)
  end

  defp primary_keys_to_binary!([], %struct{}), do: raise "No primary keys found for #{inspect struct}"
  defp primary_keys_to_binary!([key], user), do: get_primary_key_value!(key, user)
  defp primary_keys_to_binary!(keys, user) do
    keys
    |> Enum.map(&"#{&1}:#{get_primary_key_value!(&1, user)}")
    |> Enum.join("_")
  end

  defp get_primary_key_value!(key, %struct{} = user) do
    case Map.get(user, key) do
      nil -> raise "Primary key value for key `#{inspect key}` in #{inspect struct} can't be `nil`"
      val -> val
    end
  end
end
