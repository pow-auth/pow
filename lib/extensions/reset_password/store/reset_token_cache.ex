defmodule PowResetPassword.Store.ResetTokenCache do
  @moduledoc false
  use Pow.Store.Base,
    ttl: :timer.hours(2),
    namespace: "reset_token"
end
