defmodule PowEmailConfirmation.Phoenix.Router do
  def routes(_config) do
    quote location: :keep do
      resources "/confirm-email", ConfirmationController, only: [:show]
    end
  end
end
