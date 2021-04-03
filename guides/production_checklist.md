# Production checklist

Before you deploy your Pow enabled app to production, you should take a look at the following checklist to ensure that your app is ready.

The list is not exhaustive, and you should take any appropriate additional steps for your particular setup.

## REQUIRED: Use a persistent cache store

By default the `Pow.Store.Backend.EtsCache` will be used as the cache backend. In production, this would mean that all session data will be lost between deploys or server restarts. Furthermore, in clusters, the sessions will not be shared between nodes.

You should use a persistent (and possibly distributed) cache store like the `Pow.Store.Backend.MnesiaCache`.

To enable the Mnesia cache you should add it to your `application.ex` supervisor:

```elixir
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    children = [
      MyApp.Repo,
      MyAppWeb.Endpoint,
      Pow.Store.Backend.MnesiaCache
      # # Or in a distributed system:
      # {Pow.Store.Backend.MnesiaCache, extra_db_nodes: {Node, :list, []}},
      # Pow.Store.Backend.MnesiaCache.Unsplit # Recover from netsplit
    ]

    opts = [strategy: :one_for_one, name: MyAppWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # ...
end
```

Update the config with `cache_store_backend: Pow.Store.Backend.MnesiaCache`.

Mnesia will store the database files in the directory `./Mnesia.NODE` in the current working directory where `NODE` is the node name. By default, this is `./Mnesia.nonode@nohost`. You may wish to change the location to a shared directory so you can roll deploys:

```elixir
config :mnesia, :dir, '/path/to/dir'
```

`:mnesia` should be added to `:extra_applications` in `mix.exs` for it to be included in releases.

## OPTIONAL: Validate that strong passwords are used

[NIST 800-63b](https://pages.nist.gov/800-63-3/sp800-63b.html#-5112-memorized-secret-verifiers) recommends that you reject passwords that are commonly-used, expected, or compromised. The guidelines explicitly mention the following methods to ensure strong passwords are used:

> - Passwords obtained from previous breach corpuses.
> - Dictionary words.
> - Repetitive or sequential characters (e.g. ‘aaaaaa’, ‘1234abcd’).
> - Context-specific words, such as the name of the service, the username, and derivatives thereof.

You can read how to handle password breach lookup and other NIST based validation rules [on the powauth.com website](https://powauth.com/guides/2019-09-14-password-breach-lookup-and-other-password-validation-rules.html).

## OPTIONAL: Use an appropriate password hash method

By default PBKDF2-SHA512 with 100,000 iterations is used for password hashing. This is what's [recommended by NIST 800-63b](https://pages.nist.gov/800-63-3/sp800-63b.html#-5112-memorized-secret-verifiers). If you are allowed to use other password hashing algorithms, then Argon2id is [considered a safer option](https://medium.com/@mpreziuso/password-hashing-pbkdf2-scrypt-bcrypt-and-argon2-e25aaf41598e).

You can easily change the password hashing method in Pow. Here's how you can use [comeonin with Argon2](https://github.com/riverrun/argon2_elixir):

```elixir
defmodule MyApp.Users.User do
  use Ecto.Schema
  use Pow.Ecto.Schema,
    password_hash_methods: {&Argon2.hash_pwd_salt/1,
                            &Argon2.verify_pass/2}

  # ...
end
```

## OPTIONAL: Rate limit authentication attempts

You should rate limit authentication attempts according to [NIST 800-63b](https://pages.nist.gov/800-63-3/sp800-63b.html#-5112-memorized-secret-verifiers). Pow doesn't include a rate limiter since this is better dealt with at the proxy or gateway side rather than the application side. The minimum requirement would be to rate limit to a maximum of 100 failed authentication attempts per IP.

You may also wish to [lock accounts](../guides/lock_users.md) that has had too many failed authentication attempts, or require a CAPTCHA to be solved before allowing new attempts.

## OPTIONAL: Rate limit e-mail delivery

There are no rate limits for any e-mails sent out with Pow, including `PowEmailConfirmation`, `PowInvitation` and `PowResetPassword` extensions. If you use a transactional e-mail service you have to make careful considerations to prevent resource usage attacks.

Rate limitation should either be handled at the service, or you may be able to set up rate limitation in the Pow mailer. For the latter, here's a simple example using [Hammer](https://github.com/ExHammer/hammer):

```elixir
defmodule MyAppWeb.Pow.Mailer do
  use Pow.Phoenix.Mailer

  # ....

  require Logger

  @impl true
  def process(email) do
    case check_rate(email) do
      {:allow, _count} -> deliver(email)
      {:deny, _count}  -> Logger.warn("Mailer backend failed due to rate limitation: #{inspect(email)}")
    end
  end

  defp check_rate(%{to: email}) do
    Hammer.check_rate_inc("email:#{email}", :timer.minutes(1), 2, 1)
  end
end
```

In the above, the e-mail delivery will be limited to two e-mails per minute for a single recipient, but you can use different criteria, e.g. limit for e-mails that have the same recipient and subject. It's strongly recommended to add tests where appropriate to ensure abuse is not possible.
