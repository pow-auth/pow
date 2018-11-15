defmodule Pow.Test.Ecto.Repo do
  @moduledoc false
  use Ecto.Repo, otp_app: :pow, adapter: Ecto.Adapters.Postgres

  def log(_cmd), do: nil
end
