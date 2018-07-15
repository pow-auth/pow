defmodule Authex.Store.CredentialsCache do
  use Authex.Store.Base,
    ttl: :timer.hours(48),
    namespace: "credentials"
end
