defmodule PowEmailConfirmation.Phoenix.Messages do
  @moduledoc false
  def email_has_been_confirmed(_conn), do: "The email address has been confirmed."
  def email_confirmation_failed(_conn), do: "The email address couldn't be confirmed."
  def email_confirmation_required(_conn), do: "You'll need to confirm your e-mail before you can sign in. An e-mail confirmation link has been sent to you."
end
