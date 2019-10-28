defmodule PowResetPassword.NoRegistration.TestWeb.Phoenix.Endpoint do
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

  plug Pow.Plug.Session, PowResetPassword.Test.pow_config()

  plug PowResetPassword.NoRegistration.TestWeb.Phoenix.Router
end
