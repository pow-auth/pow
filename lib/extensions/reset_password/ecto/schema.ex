defmodule PowResetPassword.Ecto.Schema do
  @moduledoc false
  use Pow.Extension.Ecto.Schema.Base
  alias Pow.Extension.Ecto.Schema

  @impl true
  def validate!(_config, module) do
    Schema.require_schema_field!(module, :email, PowEmailConfirmation)
  end
end
