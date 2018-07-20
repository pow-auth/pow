defmodule Pow.Store.CredentialsCache do
  use Pow.Store.Base,
    ttl: :timer.hours(48),
    namespace: "credentials"
end
