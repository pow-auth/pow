defmodule PowLastLogin.Ecto.Context do
  @moduledoc false
  alias Pow.{Config, Ecto.Context}
  alias PowLastLogin.Ecto.Schema

  @doc """
  Updates `last_login_at` and `last_login_from`.
  """
  @spec update_last_login(Context.user(), binary, Config.t()) :: {:ok, Context.user()} | {:error, Context.changeset()}
  def update_last_login(user, login_from, config) do
    user
    |> Schema.last_login_changeset(login_from)
    |> Context.do_update(config)
  end
end
