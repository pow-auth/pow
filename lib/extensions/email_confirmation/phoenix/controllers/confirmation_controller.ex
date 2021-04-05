defmodule PowEmailConfirmation.Phoenix.ConfirmationController do
  @moduledoc false
  use Pow.Extension.Phoenix.Controller.Base

  alias Plug.Conn
  alias PowEmailConfirmation.Plug

  plug :load_user_from_confirmation_token when action in [:show]

  @spec process_show(Conn.t(), map()) :: {:ok | :error, map(), Conn.t()}
  def process_show(conn, _params), do: Plug.confirm_email(conn, %{})

  @spec respond_show({:ok | :error, map(), Conn.t()}) :: Conn.t()
  def respond_show({:ok, _user, conn}) do
    conn
    |> put_flash(:info, extension_messages(conn).email_has_been_confirmed(conn))
    |> redirect(to: redirect_to(conn))
  end
  def respond_show({:error, _changeset, conn}) do
    conn
    |> put_flash(:error, extension_messages(conn).email_confirmation_failed(conn))
    |> redirect(to: redirect_to(conn))
  end

  defp redirect_to(conn) do
    case Pow.Plug.current_user(conn) do
      nil   -> routes(conn).session_path(conn, :new)
      _user -> routes(conn).registration_path(conn, :edit)
    end
  end

  defp load_user_from_confirmation_token(%{params: %{"id" => token}} = conn, _opts) do
    case Plug.load_user_by_token(conn, token) do
      {:error, conn} ->
        conn
        |> put_flash(:error, extension_messages(conn).invalid_token(conn))
        |> redirect(to: redirect_to(conn))
        |> halt()

      {:ok, conn} ->
        conn
    end
  end
end
