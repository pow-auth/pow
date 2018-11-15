defmodule Pow.Test.Phoenix.Endpoint do
  @moduledoc false
  use Phoenix.Endpoint, otp_app: :pow

  plug Plug.RequestId
  plug Plug.Logger

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head

  plug Plug.Session,
    store: :cookie,
    key: "_binaryid_key",
    signing_salt: "secret"

  plug Pow.Plug.Session,
    current_user_assigns_key: :current_user,
    session_key: "auth",
    cache_store_backend: Pow.Test.EtsCacheMock,
    user: Pow.Test.Ecto.Users.User,
    users_context: Pow.Test.ContextMock,
    messages_backend: Pow.Test.Phoenix.Messages

  plug Pow.Test.Phoenix.Router
end
