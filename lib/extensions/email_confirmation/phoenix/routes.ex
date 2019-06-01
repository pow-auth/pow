defmodule PowEmailConfirmation.Phoenix.Routes do
  @moduledoc """
  Module that handles routes.
  """

  alias PowEmailConfirmation.Phoenix.ConfirmationController

  @doc """
  Path to redirect user to when user signs in, but e-mail hasn't been
  confirmed.

  By default this is the same as the `after_sign_in_path/1`.
  """
  def after_halted_sign_in_path(conn), do: ConfirmationController.routes(conn).after_sign_in_path(conn)

  @doc """
  Path to redirect user to when user signs up, but e-mail hasn't been
  confirmed.

  By default this is the same as the `after_registration_path/1`.
  """
  def after_halted_registration_path(conn), do: ConfirmationController.routes(conn).after_registration_path(conn)
end
