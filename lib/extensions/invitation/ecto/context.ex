defmodule PowInvitation.Ecto.Context do
  @moduledoc false
  alias Ecto.Changeset
  alias Pow.Ecto.Context
  alias PowInvitation.Ecto.Schema

  @doc """
  Creates an invited user
  """
  @spec create(map(), map(), Config.t()) :: {:ok, map()} | {:error, Changeset.t()}
  def create(inviter_user, params, config) do
    user_mod = Context.user_schema_mod(config)

    user_mod
    |> struct()
    |> user_mod.invite_changeset(inviter_user, params)
    |> Context.do_insert(config)
  end

  @doc """
  Updates an invited user and accepts invitation.
  """
  @spec update(map(), map(), Config.t()) :: {:ok, map()} | {:error, Changeset.t()}
  def update(user, params, config) do
    user
    |> Schema.accept_invitation_changeset(params)
    |> Context.do_update(config)
  end

  @doc """
  Finds an invited user by the `invitation_token` column.

  Ignores users with `:invitation_accepted_at` set.
  """
  @spec get_by_invitation_token(binary(), Config.t()) :: map() | nil
  def get_by_invitation_token(token, config) do
    [invitation_token: token]
    |> Context.get_by(config)
    |> case do
      %{invitation_accepted_at: nil} = user -> user
      _ -> nil
    end
  end
end
