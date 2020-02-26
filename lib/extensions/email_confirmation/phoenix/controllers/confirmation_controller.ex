defmodule PowEmailConfirmation.Phoenix.ConfirmationController do
  @moduledoc false
  use Pow.Extension.Phoenix.Controller.Base

  alias Plug.Conn
  alias PowEmailConfirmation.Plug
  alias PowEmailConfirmation.Phoenix.Base

  @spec process_resend_confirmation(Conn.t(), map()) :: {:ok | :error, map(), Conn.t()}
  def process_resend_confirmation(conn, _params), do: {:ok, conn}

  @spec respond_resend_confirmation({:ok | :error, map(), Conn.t()}) :: Conn.t()
  def respond_resend_confirmation({:ok, conn}) do
    conn
    |> Base.send_confirmation_email()
    |> put_flash(:success, extension_messages(conn).confirmation_email_has_been_resent(conn))
    |> redirect(to: routes(conn).after_sign_in_path(conn))
  end

  @spec process_show(Conn.t(), map()) :: {:ok | :error, map(), Conn.t()}
  def process_show(conn, %{"id" => token}), do: Plug.confirm_email(conn, token)

  @spec respond_show({:ok | :error, map(), Conn.t()}) :: Conn.t()
  def respond_show({:ok, _user, conn}) do
    conn
    |> put_flash(:success, extension_messages(conn).email_has_been_confirmed(conn))
    |> redirect(to: routes(conn).after_sign_in_path(conn))
  end
  def respond_show({:error, _changeset, conn}) do
    conn
    |> put_flash(:error, extension_messages(conn).email_confirmation_failed(conn))
    |> redirect(to: routes(conn).after_sign_in_path(conn))
  end
end
