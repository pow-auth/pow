defmodule Pow.MixProject do
  use Mix.Project

  @version "0.1.0-alpha.4"

  def project do
    [
      app: :pow,
      version: @version,
      elixir: "~> 1.6",
      elixirc_paths: elixirc_paths(Mix.env),
      start_permanent: Mix.env() == :prod,
      compilers: [:phoenix] ++ Mix.compilers,
      deps: deps(),

      # Hex
      description: "Powerful user authentication solution",
      package: package(),

      # Docs
      name: "Pow",
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: extra_applications(Mix.env),
      mod: {Pow.Application, []}
    ]
  end

  defp extra_applications(:test), do: [:ecto, :logger]
  defp extra_applications(_), do: [:logger]

  defp deps do
    [
      {:ecto, "~> 2.2.0", optional: true},
      {:phoenix, "~> 1.3.0", optional: true},
      {:plug, ">= 1.5.0 and < 1.7.0", optional: true},

      {:phoenix_html, "~> 2.11.0", only: [:dev, :test]},
      {:phoenix_ecto, "~> 3.3.0", only: [:dev, :test]},
      {:credo, "~> 0.9.3", only: [:dev, :test]},

      {:ex_doc, "~> 0.19.0", only: :dev},

      {:postgrex, ">= 0.0.0", only: [:test]},
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
        "COHERENCE_MIGRATION.md": [filename: "CoherenceMigration", title: "Migrating from Coherence"],
        "lib/extensions/email_confirmation/README.md": [filename: "PowEmailConfirmation", title: "PowEmailConfirmation"],
        "lib/extensions/persistent_session/README.md": [filename: "PowPersistentSession", title: "PowPersistentSession"],
        "lib/extensions/reset_password/README.md": [filename: "PowResetPassword", title: "PowResetPassword"]],
      groups_for_modules: [
        "Plug": ~r/^Pow.Plug/,
        "Ecto": ~r/^Pow.Ecto/,
        "Phoenix": ~r/^Pow.Phoenix/,
        "Plug extension": ~r/^Pow.Extension.Plug/,
        "Ecto extension": ~r/^Pow.Extension.Ecto/,
        "Phoenix extension": ~r/^Pow.Extension.Phoenix/,
        "Store handling": ~r/^Pow.Store/,
        "Mix helpers": ~r/^Mix.Pow/,
        "Extensions": ~r/^(PowEmailConfirmation|PowPersistentSession|PowResetPassword)/
      ],
      groups_for_extras: [
        "Extensions": Path.wildcard("lib/extensions/*/README.md"),
      ]
    ]
  end
end
