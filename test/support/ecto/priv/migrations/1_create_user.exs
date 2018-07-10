require Authex.Ecto.UserSchema

[context_app: Authex.Test.Ecto]
|> Authex.Ecto.UserSchema.migration_file()
|> Code.eval_string()
