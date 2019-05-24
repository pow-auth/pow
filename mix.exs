defmodule Pow.MixProject do
  use Mix.Project

  @version "1.0.7"

  def project do
    [
      app: :pow,
      version: @version,
      elixir: "~> 1.6",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      compilers: [:phoenix] ++ Mix.compilers(),
      deps: deps(),

      # Hex
      description: "Robust user authentication solution",
      package: package(),

      # Docs
      name: "Pow",
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: extra_applications(Mix.env()),
      mod: {Pow.Application, []}
    ]
  end

  defp extra_applications(:test), do: [:ecto, :logger]
  defp extra_applications(_), do: [:logger]

  defp deps do
    [
      {:ecto, "~> 2.2 or ~> 3.0"},
      {:phoenix, "~> 1.3.0 or ~> 1.4.0"},
      {:phoenix_html, ">= 2.0.0 and <= 3.0.0"},
      {:plug, ">= 1.5.0 and < 2.0.0", optional: true},

      {:phoenix_ecto, "~> 4.0.0", only: [:dev, :test]},
      {:credo, "~> 0.9.3", only: [:dev, :test]},

      {:ex_doc, "~> 0.19.0", only: :dev},

      {:ecto_sql, "~> 3.0.0", only: [:test]},
      {:plug_cowboy, "~> 2.0", only: [:test]},
      {:jason, "~> 1.0", only: [:test]},
      {:postgrex, "~> 0.14.0", only: [:test]}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp package do
    [
      maintainers: ["Dan Shultzer"],
      licenses: ["MIT"],
      links: %{github: "https://github.com/danschultzer/pow"},
      files: ~w(lib LICENSE mix.exs README.md)
    ]
  end

  defp docs do
    [
      source_ref: "v#{@version}",
      main: "Pow",
      canonical: "http://hexdocs.pm/pow",
      source_url: "https://github.com/danschultzer/pow",
      extras: [
        "README.md": [filename: "Pow", title: "Pow"],
        "guides/COHERENCE_MIGRATION.md": [
          filename: "CoherenceMigration",
          title: "Migrating from Coherence"
        ],
        "guides/SWOOSH_MAILER.md": [
          filename: "SwooshMailer",
          title: "Swoosh mailer"
        ],
        "guides/WHY_POW.md": [
          filename: "WhyPow",
          title: "Why use Pow?"
        ],
        "guides/USER_ROLES.md": [
          filename: "UserRoles",
          title: "How to add user roles"
        ],
        "guides/LOCK_USERS.md": [
          filename: "LockUsers",
          title: "How to disable users"
        ],
        "guides/CUSTOM_CONTROLLERS.md": [
          filename: "CustomControllers",
          title: "Custom controllers"
        ],
        "guides/DISABLE_REGISTRATION.md": [
          filename: "DisableRegistration",
          title: "Disable registration"
        ],
        "guides/REDIS_CACHE_STORE_BACKEND.md": [
          filename: "RedisCacheStoreBackend",
          title: "Redis cache store backend"
        ],
        "guides/UMBRELLA_PROJECT.md": [
          filename: "UmbrellaProject",
          title: "Pow in an umbrella project"
        ],
        "guides/MULTITENANCY.md": [
          filename: "Multitenancy",
          title: "Multitenancy with Pow"
        ],
        "lib/extensions/email_confirmation/README.md": [
          filename: "PowEmailConfirmation",
          title: "PowEmailConfirmation"
        ],
        "lib/extensions/invitation/README.md": [
          filename: "PowInvitation",
          title: "PowInvitation"
        ],
        "lib/extensions/persistent_session/README.md": [
          filename: "PowPersistentSession",
          title: "PowPersistentSession"
        ],
        "lib/extensions/reset_password/README.md": [
          filename: "PowResetPassword",
          title: "PowResetPassword"
        ]
      ],
      groups_for_modules: [
        Plug: ~r/^Pow.Plug/,
        Ecto: ~r/^Pow.Ecto/,
        Phoenix: ~r/^Pow.Phoenix/,
        "Plug extension": ~r/^Pow.Extension.Plug/,
        "Ecto extension": ~r/^Pow.Extension.Ecto/,
        "Phoenix extension": ~r/^Pow.Extension.Phoenix/,
        "Store handling": ~r/^Pow.Store/,
        "Mix helpers": ~r/^Mix.Pow/,
        Extensions: ~r/^(PowEmailConfirmation|PowPersistentSession|PowResetPassword)/
      ],
      groups_for_extras: [
        Extensions: Path.wildcard("lib/extensions/*/README.md"),
        Guides: Path.wildcard("guides/*.md")
      ]
    ]
  end
end
