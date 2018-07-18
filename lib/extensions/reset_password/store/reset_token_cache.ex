defmodule AuthexResetPassword.Store.ResetTokenCache do
  use Authex.Store.Base,
    ttl: :timer.hours(2),
    namespace: "reset_token"
end
