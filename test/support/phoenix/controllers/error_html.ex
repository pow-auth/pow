defmodule Pow.Test.Phoenix.ErrorHTML do
  @moduledoc false
  use Pow.Test.Phoenix.Web, :html

  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end
