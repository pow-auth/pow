
  defmodule Pow.Test.Phoenix.Messages do
    @moduledoc false
    use Pow.Phoenix.Messages

    def signed_in(_conn), do: "signed_in"
    def signed_out(_conn), do: "signed_out"
    def user_has_been_created(_conn), do: "user_created"
  end
