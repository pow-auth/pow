import Config

endpoint_config = [
  secret_key_base: String.duplicate("abcdefghijklmnopqrstuvxyz0123456789", 2),
  render_errors: [view: Pow.Test.Phoenix.ErrorView, accepts: ~w(html json)]
]

config :pow, Pow.Test.Phoenix.Endpoint, endpoint_config

config :pow, Pow.Test.Ecto.Repo,
  database: "pow_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  priv: "test/support/ecto/priv",
  url: System.get_env("POSTGRES_URL")

config :pow, Pow.Ecto.Schema.Password, iterations: 1

config :phoenix, :json_library, Jason

extension_test_modules = [PowEmailConfirmation, PowInvitation, PowEmailConfirmation.PowInvitation, PowPersistentSession, PowResetPassword]

for extension <- extension_test_modules do
  endpoint_module = Module.concat([extension, TestWeb.Phoenix.Endpoint])

  config :pow, endpoint_module, endpoint_config
end

config :pow, :extension_test_modules, extension_test_modules
