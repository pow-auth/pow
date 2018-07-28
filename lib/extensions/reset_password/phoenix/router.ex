defmodule PowResetPassword.Phoenix.Router do
  @moduledoc false
  use Pow.Extension.Phoenix.Router.Base

  defmacro routes(_config) do
    quote location: :keep do
      resources "/reset-password", ResetPasswordController, only: [:new, :create, :edit, :update]
    end
  end
end
