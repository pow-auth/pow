require Pow.Ecto.Schema.Migration

Pow.Test.Ecto
|> Pow.Ecto.Schema.Migration.new("users")
|> Pow.Ecto.Schema.Migration.gen()
|> Code.eval_string()
