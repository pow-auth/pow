defmodule AuthexEmailConfirmation.Plug do
  alias Authex.Plug
  alias AuthexEmailConfirmation.Ecto.Context

  @spec confirm_email(Conn.t(), binary()) :: {:ok, Conn.t()} | {:error, Conn.t()} | no_return
  def confirm_email(conn, token) do
    config = Plug.fetch_config(conn)

    config
    |> Context.get_by_confirmation_token(token)
    |> case do
      nil -> {:error, conn}
      user ->
        config
        |> Context.confirm_email(user)
        |> case do
          {:error, _user} -> {:error, conn}
          {:ok, _user}    -> {:ok, conn}
        end
    end
  end
end
