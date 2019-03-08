defmodule Mix.Tasks.Pow do
  use Mix.Task

  @shortdoc "Prints Pow help information"

  @moduledoc """
  Prints Pow tasks and their information.

      mix pow
  """

  @impl true
  def run(args) do
    case args do
      [] -> general()
      _  -> Mix.raise("Invalid arguments, expected: mix pow")
    end
  end

  defp general do
    Application.ensure_all_started(:pow)
    Mix.shell().info("Pow v#{Application.spec(:pow, :vsn)}")
    Mix.shell().info("A user authentication solution for Plug and Phoenix apps.")
    Mix.shell().info("\nAvailable tasks:\n")
    Mix.Tasks.Help.run(["--search", "pow."])
  end
end
