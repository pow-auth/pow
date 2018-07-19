defmodule AuthexEmailConfirmation.Phoenix.Messages do
  def email_has_been_confirmed(_conn), do: "The email address has been confirmed."
  def email_confirmation_failed(_conn), do: "The email address couldn't be confirmed."
end
