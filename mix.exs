defmodule Authex.MixProject do
  use Mix.Project

  def project do
    [
      app: :authex,
      version: "0.1.0",
      elixir: "~> 1.6",
      elixirc_paths: elixirc_paths(Mix.env),
      start_permanent: Mix.env() == :prod,
      compilers: [:phoenix] ++ Mix.compilers,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: extra_applications(Mix.env),
      mod: {Authex.Application, []}
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
      {:phoenix_html, "~> 2.11", only: [:test]},
      {:postgrex, ">= 0.0.0", only: [:test]}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
