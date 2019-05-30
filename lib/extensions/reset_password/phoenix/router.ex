defmodule PowResetPassword.Phoenix.Router do
  @moduledoc false
  use Pow.Extension.Phoenix.Router.Base

  alias Pow.Phoenix.Router

  defmacro routes(_config) do
    quote location: :keep do
      Router.pow_resources "/reset-password", ResetPasswordController, only: [:new, :create, :update]
      Router.pow_route :get, "/reset-password/:id", ResetPasswordController, :edit
    end
  end
end
