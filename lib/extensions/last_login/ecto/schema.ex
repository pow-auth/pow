defmodule PowLastLogin.Ecto.Schema do
  @moduledoc false
  use Pow.Extension.Ecto.Schema.Base
  alias Ecto.Changeset

  @impl true
  def attrs(_config) do
    [
      {:current_login_at, :utc_datetime},
      {:current_login_from, :string},
      {:last_login_at, :utc_datetime},
      {:last_login_from, :string}
    ]
  end

  @spec last_login_changeset(Ecto.Schema.t(), String.t()) :: Changeset.t()
  def last_login_changeset(%Changeset{data: %user_mod{} = user} = changeset, login_from) do
    login_at = Pow.Ecto.Schema.__timestamp_for__(user_mod, :last_login_at)

    changeset
    |> Changeset.put_change(:last_login_at, user.current_login_at)
    |> Changeset.put_change(:last_login_from, user.current_login_from)
    |> Changeset.put_change(:current_login_at, login_at)
    |> Changeset.put_change(:current_login_from, login_from)
  end
  def last_login_changeset(user, login_from) do
    user
    |> Changeset.change()
    |> last_login_changeset(login_from)
  end
end
