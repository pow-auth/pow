defmodule Pow.MixProject do
  use Mix.Project

  @version "1.0.20"

  def project do
    [
      app: :pow,
      version: @version,
      elixir: "~> 1.7",
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
      {:phoenix, ">= 1.3.0 and < 1.6.0"},
      {:phoenix_html, ">= 2.0.0 and <= 3.0.0"},
      {:plug, ">= 1.5.0 and < 2.0.0", optional: true},

      {:phoenix_ecto, "~> 4.1.0", only: [:dev, :test]},
      {:credo, "~> 1.2.0", only: [:dev, :test]},
      {:jason, "~> 1.0", only: [:dev, :test]}, # Credo requires jason to exist also in :dev

      {:ex_doc, "~> 0.21.0", only: :dev},

      {:ecto_sql, "~> 3.3", only: [:test]},
      {:plug_cowboy, "~> 2.1", only: [:test]},
      {:postgrex, "~> 0.15.3", only: [:test]}
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
      markdown_processor: ExDoc.Pow.Markdown,
      source_ref: "v#{@version}",
      main: "README",
      canonical: "http://hexdocs.pm/pow",
      source_url: "https://github.com/danschultzer/pow",
      logo: "assets/logo.svg",
      assets: "assets",
      extras: [
        "README.md": [filename: "README"],
        "CONTRIBUTING.md": [filename: "CONTRIBUTING"],
        "CHANGELOG.md": [filename: "CHANGELOG"],
        "guides/why_pow.md": [],
        "guides/production_checklist.md": [],
        "guides/security_practices.md": [],
        "guides/coherence_migration.md": [],
        "guides/configuring_mailer.md": [],
        "guides/user_roles.md": [],
        "guides/lock_users.md": [],
        "guides/custom_controllers.md": [],
        "guides/disable_registration.md": [],
        "guides/redis_cache_store_backend.md": [],
        "guides/umbrella_project.md": [],
        "guides/multitenancy.md": [],
        "guides/sync_user.md": [],
        "guides/api.md": [],
        "lib/extensions/email_confirmation/README.md": [filename: "pow_email_confirmation"],
        "lib/extensions/invitation/README.md": [filename: "pow_invitation"],
        "lib/extensions/persistent_session/README.md": [filename: "pow_persistent_session"],
        "lib/extensions/reset_password/README.md": [filename: "pow_reset_password"]
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
        "PowEmailConfirmation": ~r/^PowEmailConfirmation/,
        "PowPersistentSession": ~r/^PowPersistentSession/,
        "PowResetPassword": ~r/^PowResetPassword/,
        "PowInvitation": ~r/^PowInvitation/
      ],
      groups_for_extras: [
        Extensions: Path.wildcard("lib/extensions/*/README.md"),
        Guides: Path.wildcard("guides/*.md")
      ]
    ]
  end
end
