defmodule PowRateLimiter.Phoenix.Messages do
  @moduledoc false

  @doc """
  Flash message to show when the connection has been rate limited.
  """
  def rate_limited(_conn), do: "You have attempted sign in too many times. Please wait a while before you try again."
end
