use Mix.Config

config :authex, Authex.Test.Phoenix.Endpoint,
  secret_key_base: String.duplicate("abcdefghijklmnopqrstuvxyz0123456789", 2),
  render_errors: [view: Authex.Test.Phoenix.ErrorView, accepts: ~w(html json)]

config :authex, Authex.Test.Ecto.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "authex_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  priv: "test/support/ecto/priv"

config :pbkdf2_elixir, rounds: 1
