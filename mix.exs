defmodule Pow.MixProject do
  use Mix.Project

  @version "0.1.0-alpha"

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
     docs: [source_ref: "v#{@version}", main: "Pow",
            canonical: "http://hexdocs.pm/pow",
            source_url: "https://github.com/danschultzer/pow",
            extras: ["README.md"]]
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
      {:uuid, "~> 1.0"},
      {:comeonin, "~> 4.1"},
      {:pbkdf2_elixir, "~> 0.12"},
      {:ecto, "~> 2.2", optional: true},
      {:phoenix, "~> 1.3", optional: true},
      {:plug, "~> 1.6", optional: true},
      {:phoenix_html, "~> 2.11", only: [:dev, :test]},
      {:phoenix_ecto, "~> 3.3", only: [:dev, :test]},
      {:postgrex, ">= 0.0.0", only: [:test]},
      {:ex_doc, "~> 0.18", only: :dev, runtime: false},
      {:credo, "~> 0.9.3", only: :dev}
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
end
