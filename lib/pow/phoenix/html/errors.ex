defmodule Pow.Phoenix.HTML.ErrorHelpers do
  @moduledoc """
  Conveniences for building error messages.
  """
  alias Phoenix.HTML.Tag

  @doc """
  Generates tag for inlined form input errors.

  It'll call a simple mock function to interpolate, as translations should be
  handled in the Phoenix app implementing Pow.
  """
  def error_tag(form, field) do
    form.errors
    |> Keyword.get_values(field)
    |> Enum.map(&error_tag/1)
  end
  def error_tag(error) do
    Tag.content_tag(:span, translate_error(error), class: "help-block")
  end

  defp translate_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, msg ->
      token = "%{#{key}}"

      case String.contains?(msg, token) do
        true  -> String.replace(msg, token, to_string(value), global: false)
        false -> msg
      end
    end)
  end
end
