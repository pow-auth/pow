defmodule Pow.Test.Phoenix.Routes do
  @moduledoc false
  use Pow.Phoenix.Routes

  def after_sign_out_path(_conn), do: "/signed_out"
end
