defmodule Pow.Test.Mix.TestCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  setup_all do
    clear_tmp_files()

    :ok
  end

  setup do
    current_shell = Mix.shell()

    on_exit fn ->
      Mix.shell(current_shell)
    end

    Mix.shell(Mix.Shell.Process)

    :ok
  end

  defp clear_tmp_files, do: File.rm_rf!("tmp")
end
