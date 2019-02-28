defmodule Mix.Pow.Extension do
  @moduledoc """
  Utilities module for mix extension tasks.
  """
  alias Pow.Config

  @spec extensions(map(), atom()) :: [atom()]
  def extensions(config, otp_app) do
    config
    |> Map.get(:extension, [])
    |> List.wrap()
    |> Enum.map(&Module.concat(Elixir, &1))
    |> maybe_fetch_otp_app_extensions(otp_app)
  end

  defp maybe_fetch_otp_app_extensions([], otp_app) do
    Config.get([otp_app: otp_app], :extensions, [])
  end
  defp maybe_fetch_otp_app_extensions(extensions, _otp_app), do: extensions

  @spec no_extensions_error(atom()) :: :ok
  def no_extensions_error(otp_app) do
    Mix.shell.error("No extensions was provided as arguments, or found in `config :#{otp_app}, :pow` configuration.")
  end
end
