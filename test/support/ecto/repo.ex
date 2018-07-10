defmodule Authex.Test.Ecto.Repo do
  use Ecto.Repo, otp_app: :authex

  def log(_cmd), do: nil
end
