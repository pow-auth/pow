defmodule PowRateLimiter.Engine do
  @moduledoc """
  Used for rate limiter engines.

  ## Usage

      defmodule MyAppWeb.RateLimiter do
        @behaviour PowRateLimiter.Engine

        @impl true
        def check_rate(user_fingerprint, conn, config) do
          # ...
        end

        def clear_rate(user_fingerprint, conn, config) do
          # ...
        end

        def increase_rate(user_fingerprint, conn, config) do
          # ...
        end
      end
  """

  alias Plug.Conn
  alias Pow.Config

  @callback increase_rate_check(Config.t(), Conn.t(), binary()) :: {:allow, term()} | {:deny, term()}
  @callback clear_rate(Config.t(), Conn.t(), binary()) :: :ok
end
