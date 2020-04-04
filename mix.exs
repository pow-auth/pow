defmodule Pow.MixProject do
  use Mix.Project

  @version "1.0.19"

  def project do
    [
      app: :pow,
      version: @version,
      elixir: "~> 1.6",
      elixirc_paths: elixirc_paths(Mix.env(), optional_deps()),
      start_permanent: Mix.env() == :prod,
      compilers: compilers(optional_deps()),
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
      {:ecto, "~> 2.2 or ~> 3.0", optional: true},
      {:phoenix, "~> 1.3.0 or ~> 1.4.0", optional: true},
      {:phoenix_html, ">= 2.0.0 and <= 3.0.0", optional: true},
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

  def elixirc_paths(:test, _optional_deps), do: ["lib", "test/support"]
  def elixirc_paths(_, optional_deps) do
    case optional_deps_missing?(optional_deps) do
      true -> paths_without_missing_optional_deps(optional_deps)
      false  -> ["lib"]
    end
  end

  def compilers(optional_deps) do
    case phoenix_missing?(optional_deps) do
      true  -> [:phoenix] ++ Mix.compilers
      _     -> Mix.compilers()
    end
  end

  defp phoenix_missing?(optional_deps) do
    Keyword.get(optional_deps, :phoenix)
  end

  defp optional_deps_missing?(optional_deps) do
    not Enum.empty?(optional_deps_missing(optional_deps))
  end

  defp optional_deps_missing(optional_deps) do
    Enum.reject(optional_deps, &elem(&1, 1))
  end

  defp optional_deps do
    for dep <- [:phoenix, :phoenix_html, :ecto, :plug] do
      case Mix.ProjectStack.peek() do
        %{config: config} -> {dep, Keyword.has_key?(config[:deps], dep)}
        _                 -> {dep, true}
      end
    end
  end

  defp paths_without_missing_optional_deps(optional_deps) do
    deps = optional_deps_missing(optional_deps)

    "lib/**/*.ex"
    |> Path.wildcard()
    |> Enum.reject(&reject_deps_path?(deps, &1))
  end

  defp reject_deps_path?(deps, path) do
    Enum.any?(deps, &String.contains?(path, "/#{elem(&1, 0)}"))
  end

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
