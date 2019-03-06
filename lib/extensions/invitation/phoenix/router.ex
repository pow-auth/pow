defmodule PowInvitation.Phoenix.Router do
  @moduledoc false
  use Pow.Extension.Phoenix.Router.Base

  defmacro routes(_config) do
    quote location: :keep do
      resources "/invitations", InvitationController, only: [:new, :create, :show, :edit, :update]
    end
  end
end
