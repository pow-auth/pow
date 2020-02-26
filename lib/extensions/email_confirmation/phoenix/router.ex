defmodule PowEmailConfirmation.Phoenix.Router do
  @moduledoc false
  use Pow.Extension.Phoenix.Router.Base

  alias Pow.Phoenix.Router

  defmacro routes(_config) do
    quote location: :keep do
      Router.pow_resources "/confirm-email", ConfirmationController, only: [:show]
      Router.pow_route :post, "/resend-confirmation", ConfirmationController, :resend_confirmation
    end
  end
end
