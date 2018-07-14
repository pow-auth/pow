defmodule Authex.Test.Phoenix.Endpoint do
  use Phoenix.Endpoint, otp_app: :authex

  plug Plug.RequestId
  plug Plug.Logger

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Poison

  plug Plug.MethodOverride
  plug Plug.Head

  plug Plug.Session,
    store: :cookie,
    key: "_binaryid_key",
    signing_salt: "secret"

  plug Authex.Plug.Session,
    current_user_assigns_key: :current_user,
    session_key: "auth",
    session_store: Authex.Test.CredentialsCacheMock,
    credentials_cache_name: "credentials",
    credentials_cache_ttl: :timer.hours(48),
    user: Authex.Test.Ecto.Users.User,
    users_context: Authex.Test.ContextMock

  plug Authex.Test.Phoenix.Router
end
