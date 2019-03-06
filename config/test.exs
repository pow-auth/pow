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
