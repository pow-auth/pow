defmodule Pow.Phoenix.HTML.FormTemplate do
  @moduledoc """
  Module that can build user form templates for Phoenix.
  """

  @template EEx.compile_string(
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

  @doc """
  Renders a form.

  ## Options

    * `:button_label` - the submit button label, defaults to "Submit".
  """
  @spec render(list(), Keyword.t()) :: Macro.t()
  def render(inputs, opts \\ []) do
    button_label = Keyword.get(opts, :button_label, "Submit")

    render_form(inputs, button_label)
  end

  defp render_form(inputs, button_label) do
    inputs = for {type, key} <- inputs, do: input(type, key)

    unquote(@template)
  end

  defp input(:text, key) do
    {label(key), ~s(<%= text_input f, #{inspect_key(key)} %>), error(key)}
  end
  defp input(:password, key) do
    {label(key), ~s(<%= password_input f, #{inspect_key(key)} %>), error(key)}
  end

  defp label(key) do
    ~s(<%= label f, #{inspect_key(key)} %>)
  end

  defp error(key) do
    ~s(<%= error_tag f, #{inspect_key(key)} %>)
  end

  @doc false
  @spec inspect_key(any()) :: binary()
  def inspect_key({:changeset, :pow_user_id_field}), do: "Pow.Ecto.Schema.user_id_field(@changeset)"
  def inspect_key(key), do: inspect(key)
end
