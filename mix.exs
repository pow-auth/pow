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
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:plug, "~> 1.6", optional: true},
      {:uuid, "~> 1.0"},
      {:phoenix, "~> 1.3", optional: true},
      {:phoenix_html, "~> 2.11", only: [:test, :dev]},
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
