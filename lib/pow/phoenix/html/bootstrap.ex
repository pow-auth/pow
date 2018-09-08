defmodule Pow.Phoenix.HTML.Bootstrap do
  # TODO: Remove module by 1.1.0 and only support Phoenix 1.4.0

  @moduledoc """
  Module that helps build HTML for Phoenix with Bootstrap CSS.
  """
  import Pow.Phoenix.HTML.FormTemplate, only: [inspect_key: 1]

  @form_template EEx.compile_string(
    """
    <%%= form_for @changeset, @action, [as: :user], fn f -> %>
      <%%= if @changeset.action do %>
        <div class="alert alert-danger">
          <p>Oops, something went wrong! Please check the errors below.</p>
        </div>
      <%% end %>
    <%= for {label, input, error} <- inputs, input do %>
      <div class="form-group">
        <%= label %>
        <%= input %>
        <%= error %>
      </div>
    <% end %>
      <div class="form-group">
        <%%= submit <%= inspect button_label %>, class: "btn btn-primary" %>
      </div>
    <%% end %>
    """)

  @doc """
  Renders a form.
  """
  @spec render_form(list(), binary()) :: Macro.t()
  def render_form(inputs, button_label) do
    inputs = for {type, key} <- inputs, do: input(type, key)

    unquote(@form_template)
  end

  defp input(:text, key) do
    {label(key), ~s(<%= text_input f, #{inspect_key(key)}, class: "form-control" %>), error(key)}
  end
  defp input(:password, key) do
    {label(key), ~s(<%= password_input f, #{inspect_key(key)}, class: "form-control" %>), error(key)}
  end

  defp label(key) do
    ~s(<%= label f, #{inspect_key(key)}, class: "control-label" %>)
  end

  defp error(key) do
    ~s(<%= error_tag f, #{inspect_key(key)} %>)
  end
end
