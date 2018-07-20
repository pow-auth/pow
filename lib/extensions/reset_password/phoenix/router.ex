defmodule PowResetPassword.Phoenix.Router do
  def routes(_config) do
    quote location: :keep do
      resources "/reset-password", ResetPasswordController, only: [:new, :create, :edit, :update]
    end
  end
end
