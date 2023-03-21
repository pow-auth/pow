# TODO: Remove module when requiring Phoenix 1.7.0
unless Pow.dependency_vsn_match?(:phoenix, ">= 1.7.0") do
defmodule Pow.Phoenix.HTML.Minimalist do
  @moduledoc false

  @form_template EEx.compile_string(
    """
    <%%= form_for @changeset, @action, [as: :user], fn f -> %>
      <%%= if @changeset.action do %>
        <div class="alert alert-danger">
          <p>Oops, something went wrong! Please check the errors below.</p>
        </div>
      <%% end %>
    <%= for {label, input, error} <- inputs, input do %>
      <%= label %>
      <%= input %>
      <%= error %>
    <% end %>
      <div>
        <%%= submit <%= inspect button_label %> %>
      </div>
    <%% end %>
    """)

  def render_form(inputs, opts \\ []) do
    button_label = Keyword.get(opts, :button_label, "Submit")

    inputs = for {type, key} <- inputs, do: input(type, key)

    unquote(@form_template)
  end

  defp input(:text, key) do
    {label(key), ~s(<%= text_input f, #{inspect_key(key)} %>), error(key)}
  end
  defp input(:password, key) do
    {label(key), ~s(<%= password_input f, #{inspect_key(key)} %>), error(key)}
  end

  defp inspect_key({:changeset, :pow_user_id_field}), do: "Pow.Ecto.Schema.user_id_field(@changeset)"
  defp inspect_key(key), do: inspect(key)

  defp label(key) do
    ~s(<%= label f, #{inspect_key(key)} %>)
  end

  defp error(key) do
    ~s(<%= error_tag f, #{inspect_key(key)} %>)
  end
end
end
