defmodule PowInvitation.Ecto.Context do
  @moduledoc """
  Handles invitation context for user.
  """
  alias Pow.{Config, Ecto.Context, Operations}

  @doc """
  Creates an invited user.

  See `PowInvitation.Ecto.Schema.invite_changeset/3`.
  """
  @spec create(Context.user(), map(), Config.t()) :: {:ok, Context.user()} | {:error, Context.changeset()}
  def create(inviter_user, params, config) do
    user_mod = Config.user!(config)

    user_mod
    |> struct()
    |> user_mod.invite_changeset(inviter_user, params)
    |> Context.do_insert(config)
  end

  @doc """
  Updates an invited user and accepts invitation.

  See `PowInvitation.Ecto.Schema.accept_invitation_changeset/2`.
  """
  @spec update(Context.user(), map(), Config.t()) :: {:ok, Context.user()} | {:error, Context.changeset()}
  def update(%user_mod{} = user, params, config) do
    user
    |> user_mod.accept_invitation_changeset(params)
    |> Context.do_update(config)
  end

  @doc """
  Finds an invited user by the `invitation_token` column.

  Ignores users with `:invitation_accepted_at` set.
  """
  @spec get_by_invitation_token(binary(), Config.t()) :: Context.user() | nil
  def get_by_invitation_token(token, config) do
    [invitation_token: token]
    |> Operations.get_by(config)
    |> case do
      %{invitation_accepted_at: nil} = user -> user
      _ -> nil
    end
  end
end
