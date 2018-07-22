defmodule PowResetPassword.Ecto.Schema do
  @moduledoc false
  use Pow.Extension.Ecto.Schema.Base
  alias Pow.Config

  def validate!(config, user_id_field) do
    case user_id_field do
      :email -> config
      _      -> raise_user_id_field_not_email_error()
    end
  end

  @spec raise_user_id_field_not_email_error :: no_return
  defp raise_user_id_field_not_email_error do
    Config.raise_error("The `:user_id_field` has to be `:email` for PowResetPassword extension to work")
  end
end
