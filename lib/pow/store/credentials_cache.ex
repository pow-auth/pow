defmodule Pow.Store.CredentialsCache do
  @moduledoc """
  Default module for credentials session storage.

  A key (session id), is used to store, fetch or delete credentials. When
  credentials are stored or deleted, a credentials key will be generated.
  The value of that key will be all current keys (session ids), and the
  most recent credentials.

  When a key is updated, all expired keys will be pruned from the credentials
  key.
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
  """
  @spec put(Config.t(), Config.t(), binary(), any()) :: :ok
  def put(config, backend_config, session_id, user) do
    key = append_to_session_list(config, backend_config, session_id, user)

    Base.put(config, backend_config, session_id, key)
  end

  @doc """
  Delete the sesison id from the backend store.

  This will delete the session id from the session list for the user
  credentials in the backend store. If the session id is the only one in the
  session list, the user credentials will be deleted too from the backend
  store.
  """
  @spec delete(Config.t(), Config.t(), binary()) :: :ok
  def delete(config, backend_config, session_id) do
    key = Base.get(config, backend_config, session_id)

    Base.delete(config, backend_config, session_id)
    delete_from_session_list(config, backend_config, session_id, key)
  end

  @doc """
  Fetch user credentials from the backend store from session id.
  """
  @spec get(Config.t(), Config.t(), binary()) :: any() | :not_found
  def get(config, backend_config, session_id) do
    key = Base.get(config, backend_config, session_id)

    case Base.get(config, backend_config, key) do
      %{user: user} -> user
      :not_found    -> :not_found
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

  defp user_session_list_key(%struct{id: id}) do
    "#{Macro.underscore(struct)}_sessions_#{id}"
  end
end
