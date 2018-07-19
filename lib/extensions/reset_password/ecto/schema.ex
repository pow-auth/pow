defmodule AuthexResetPassword.Ecto.Schema do
  use Authex.Extension.Ecto.Schema.Base
  alias Authex.Config

  def validate!(config, login_field) do
    case login_field do
      :email -> config
      _      -> raise_login_field_not_email_error()
    end
  end

  @spec raise_login_field_not_email_error :: no_return
  defp raise_login_field_not_email_error() do
    Config.raise_error("The `:login_field` has to be `:email` for AuthexResetPassword extension to work")
  end
end
