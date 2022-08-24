# Migrating from Coherence

## Remove coherence

First, we'll remove coherence.

  1. Remove `:coherence` config from `config/config.exs` (also any coherence config in `config/dev.exs`, `config/prod.exs` and `config/test.exs`)
  2. Delete `coherence_messages.ex`, `coherence_web.ex`, `coherence/redirects.ex`, `emails/coherence`, `templates/coherence`, and `views/coherence`.
  3. Remove coherence from `user.ex`. This includes the coherence specific changeset function `def changeset(model, params, :password)`, and the `:email` field in schema.
  4. Remove coherence from `router.ex`. Pipeline `:public` can be removed entirely if it's only used for coherence, as well as scopes that only contains coherence routes.
  5. Remove `:coherence` from `mix.exs` and run `mix deps.unlock coherence`

## Add Pow to your Ecto schema

Set up a migration file with the following change to continue using your users table:

  ```elixir
  def up do
    alter table(:users) do
      add :email_confirmation_token, :string
      add :email_confirmed_at,       :utc_datetime
      add :unconfirmed_email,        :string
    end

    create unique_index(:users, :email_confirmation_token)
  end

  def down do
    alter table(:users) do
      remove :email_confirmation_token
      remove :email_confirmed_at
      remove :unconfirmed_email
    end
  end
  ```

Add configuration:

```elixir
config :my_app, :pow,
  repo: MyApp.Repo,
  user: MyApp.User,
  extensions: [PowEmailConfirmation, PowResetPassword],
  controller_callbacks: Pow.Extension.Phoenix.ControllerCallbacks,
  mailer_backend: MyAppWeb.Pow.Mailer
```

Set up `user.ex` to use Pow:

  ```elixir
  defmodule MyApp.User do
    use Ecto.Schema
    use Pow.Ecto.Schema
    use Pow.Extension.Ecto.Schema,
      extensions: [PowEmailConfirmation, PowResetPassword]

    schema "users" do
      # ...

      pow_user_fields()

      timestamps()
    end

    # ...

    @spec changeset(t(), map()) :: Changeset.t()
    def changeset(model, params \\ %{}) do
      model
      |> cast(params, [:email])
      |> pow_changeset(params)
      |> pow_extension_changeset(params)
    end
  end
  ```

## Continue with bcrypt hashing

Coherence uses bcrypt, so you'll have to switch to bcrypt in Pow:

 1. Install bcrypt in `mix.exs`:

    ```elixir
    {:bcrypt_elixir, "~> 2.0"}
    ```

 2. Set up `user.ex` to use bcrypt for password hashing:

    ```elixir
    defmodule MyApp.User do
      use Ecto.Schema
      use Pow.Ecto.Schema,
        password_hash_methods: {&Bcrypt.hash_pwd_salt/1,
                                &Bcrypt.verify_pass/2}

      # ...
    end
    ```

## Mailer

Set up `WEB_PATH/pow/mailer.ex` to enable emails:

  ```elixir
  defmodule MyAppWeb.Pow.Mailer do
    @moduledoc false
    use Pow.Phoenix.Mailer
    use Swoosh.Mailer, otp_app: :my_app

    import Swoosh.Email

    def cast(email) do
      new()
      |> from({"My App", "myapp@example.com"})
      |> to({"", email.user.email})
      |> subject(email.subject)
      |> text_body(email.text)
      |> html_body(email.html)
    end

    def process(email), do: deliver(email)
  end
  ```

## Phoenix

Add session plug to `endpoint.ex`:

  ```elixir
  # After plug Plug.Session

  plug Pow.Plug.Session, otp_app: :my_app
  ```

Set up `router.ex`

  ```elixir
  defmodule MyAppWeb.Router do
    use Phoenix.Router
    use Pow.Phoenix.Router
    use Pow.Extension.Phoenix.Router, otp_app: :my_app

    # pipelines ...

    pipeline :protected do
      plug Pow.Plug.RequireAuthenticated,
        error_handler: Pow.Phoenix.PlugErrorHandler
    end

    scope "/" do
      pipe_through :browser

      pow_routes()
      pow_extension_routes()
    end

    # routes ...
  end
  ```

Change `Routes.session_path` to `Routes.pow_session_path`, and
`Routes.registration_path` to `Routes.pow_registration_path`. Any references to `Coherence.current_user/1`, can be changed to `Pow.Plug.current_user/1`.

That's it! You can now test out your Pow'ered app and then remove all unused fields/tables after.

## Keep confirmed_at and confirmation_token data

To keep confirmed_at and confirmation_token data from your past coherence setup, you should first add the coherence fields to your user schema:

```elixir
field :confirmation_token, :string
field :confirmed_at, :utc_datetime
```

And then you can run the following:

```elixir
alias MyApp.{User, Repo}

User
|> Repo.all()
|> Enum.each(fn user ->
  user
  |> Ecto.Changeset.change(%{
    email_confirmation_token: user.confirmation_token,
    email_confirmed_at: user.confirmed_at
    })
  |> Repo.update!()
end)
```
