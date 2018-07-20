defmodule Pow.Test.Ecto.Repo do
  use Ecto.Repo, otp_app: :pow

  def log(_cmd), do: nil
end
