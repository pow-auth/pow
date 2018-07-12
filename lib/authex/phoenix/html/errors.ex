defmodule Authex.Phoenix.HTML.ErrorHelpers do
  @moduledoc """
  Conveniences for building error messages.
  """
  alias Phoenix.HTML.Tag

  @doc """
  Generates tag for inlined form input errors.
  """
  def error_tag(form, field) do
    form.errors
    |> Keyword.get_values(field)
    |> Enum.map(&error_tag/1)
  end
  def error_tag({msg, _opts}) do
    Tag.content_tag(:span, msg, class: "help-block")
  end
end
