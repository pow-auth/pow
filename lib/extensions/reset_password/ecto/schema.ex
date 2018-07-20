defmodule PowResetPassword.Ecto.Schema do
  @moduledoc false
  use Pow.Extension.Ecto.Schema.Base
  alias Pow.Config

  def validate!(config, login_field) do
    case login_field do
      :email -> config
      _      -> raise_login_field_not_email_error()
    end
  end

  @spec raise_login_field_not_email_error :: no_return
  defp raise_login_field_not_email_error do
    Config.raise_error("The `:login_field` has to be `:email` for PowResetPassword extension to work")
  end
end
