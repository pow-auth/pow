defmodule Pow.Plug do
  @moduledoc false

  @deprecation_msg "Pow.Plug will be removed in the next version, please use Pow.Plug.Helpers instead."

  @deprecated @deprecation_msg
  defdelegate current_user(conn), to: Pow.Plug.Helpers

  @deprecated @deprecation_msg
  defdelegate assign_current_user(conn, user, config), to: Pow.Plug.Helpers

  @deprecated @deprecation_msg
  defdelegate put_config(conn, config), to: Pow.Plug.Helpers

  @deprecated @deprecation_msg
  defdelegate fetch_config(conn), to: Pow.Plug.Helpers

  @deprecated @deprecation_msg
  defdelegate authenticate_user(conn, params), to: Pow.Plug.Helpers

  @deprecated @deprecation_msg
  defdelegate clear_authenticated_user(conn), to: Pow.Plug.Helpers

  @deprecated @deprecation_msg
  defdelegate change_user(conn, params), to: Pow.Plug.Helpers

  @deprecated @deprecation_msg
  defdelegate create_user(conn, params), to: Pow.Plug.Helpers

  @deprecated @deprecation_msg
  defdelegate update_user(conn, params), to: Pow.Plug.Helpers

  @deprecated @deprecation_msg
  defdelegate delete_user(conn), to: Pow.Plug.Helpers
end
