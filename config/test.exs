use Mix.Config

config :pow, Pow.Test.Phoenix.Endpoint,
  secret_key_base: String.duplicate("abcdefghijklmnopqrstuvxyz0123456789", 2),
  render_errors: [view: Pow.Test.Phoenix.ErrorView, accepts: ~w(html json)]

config :pow, Pow.Test.Ecto.Repo,
  database: "pow_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  priv: "test/support/ecto/priv"

config :mnesia, dir: 'tmp/mnesia'

config :pow, Pow.Ecto.Schema.Password, iterations: 1

config :phoenix, :json_library, Jason

extension_test_modules = [PowEmailConfirmation, PowPersistentSession, PowResetPassword]

for extension <- extension_test_modules do
  endpoint_module = Module.concat([extension, TestWeb.Phoenix.Endpoint])

  config :pow, endpoint_module,
    render_errors: [view: Pow.Test.Phoenix.ErrorView, accepts: ~w(html json)],
    secret_key_base: String.duplicate("abcdefghijklmnopqrstuvxyz0123456789", 2)
end

config :pow, :extension_test_modules, extension_test_modules
