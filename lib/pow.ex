defmodule Pow do
  @moduledoc false

  alias Pow.Config

  @doc """
  Checks for version requirement in dependencies.
  """
  @spec dependency_vsn_match?(atom(), binary()) :: boolean()
  def dependency_vsn_match?(dep, req) do
    case :application.get_key(dep, :vsn) do
      {:ok, actual} ->
        actual
        |> List.to_string()
        |> Version.match?(req)

      _any ->
        false
    end
  end

  @doc """
  Dispatches a telemetry event.

  This will dispatch an event with `:telemetry`, if `:telemetry` is available.

  You can attach to these event in Pow. Here's a common example of attaching
  to the telemetry events of session lifecycle to log them:

      defmodule MyAppWeb.Pow.TelemetryListener do
        require Logger

        def install do
          events = [
            [:pow, :plug, :session, :create],
            [:pow, :plug, :session, :delete],
            [:pow, :plug, :session, :renew]
          }]

          :ok = :telemetry.attach_many("my-app-log-handler", events, &handle_event/4, :ok)
        end

        def handle_event([:pow, :plug, :sesssion, :create], _measurements, metadata, _config) do
          Logger.info("[Pow.Plug.Session] Session \#{metadata.session_fingerprint} initiated for user \#{metadata.user.id}")
        end
        def handle_event([:pow, :plug, :sesssion, :delete], _measurements, metadata, _config) do
          Logger.info("[Pow.Plug.Session] Session \#{metadata.session_fingerprint} has been deleted")
        end
        def handle_event([:pow, :plug, :sesssion, :renew], _measurements, metadata, _config) do
          Logger.info("[Pow.Plug.Session] Session \#{metadaa.session_fingerprint} has renewed")
        end
      end

  Now you can set call `MyAppWeb.Pow.TelemetryListener.install()`.
  """
  @spec telemetry_event(Config.t(), [atom()], atom(), map(), map()) :: :ok
  def telemetry_event(config, event, action, metadata, measurements \\ %{}) do
    loaded = Code.ensure_loaded?(:telemetry)
    log?   = Config.get(config, :log_telemetry?, true)
    event  = event ++ [action]

    case loaded and log? do
      true ->
        :telemetry.execute(event, measurements, metadata)

      false ->
        :error
    end
  end
end
