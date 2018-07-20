defmodule Pow.Test.Ecto.Repo do
  @moduledoc false
  use Ecto.Repo, otp_app: :pow

  def log(_cmd), do: nil
end
