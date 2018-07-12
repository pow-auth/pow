defmodule Authex.Test.Mix.TestCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  setup_all do
    clear_tmp_files()

    :ok
  end

  defp clear_tmp_files(), do: File.rm_rf!("tmp")
end
