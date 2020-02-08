defmodule Pow.Test.Phoenix.Endpoint do
  defmodule SessionPlugHelper do
    @moduledoc false
    alias Pow.Plug.Session

    def init(config), do: Session.init(config)

    def call(conn, config) do
      additional_config =
        case conn.private[:pow_test_config] do
          :username_user -> [user: Pow.Test.Ecto.Users.UsernameUser, users_context: Pow.Test.ContextMock.UsernameUser]
          nil            -> [user: Pow.Test.Ecto.Users.User, users_context: Pow.Test.ContextMock]
          additional     -> additional
        end

      Session.call(conn, Keyword.merge(config, additional_config))
    end
  end

  @moduledoc false
  use Phoenix.Endpoint, otp_app: :pow

  @session_options [
    store: :cookie,
    key: "_binaryid_key",
    signing_salt: "secret"
  ]

  @pow_config [
    current_user_assigns_key: :current_user,
    session_key: "auth",
    cache_store_backend: Pow.Test.EtsCacheMock,
    messages_backend: Pow.Test.Phoenix.Messages,
    routes_backend: Pow.Test.Phoenix.Routes
  ]

  plug Plug.RequestId
  plug Plug.Logger

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head

  plug Plug.Session, @session_options
  plug SessionPlugHelper, @pow_config
  plug Pow.Test.Phoenix.Router
end
