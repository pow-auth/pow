
defmodule Pow.Phoenix.HTML.FormTemplate do
  @moduledoc """
  Module that can build form templates for Phoenix.
  """
  @template EEx.compile_string """
  <%%= form_for @changeset, @action, fn f -> %>
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
  """

  @spec render(list(), Keyword.t()) :: Macro.t()
  def render(inputs, opts \\ []) do
    inputs       = for {type, key} <- inputs, do: input(type, key)
    button_label = Keyword.get(opts, :button_label, "Submit")

    unquote(@template)
  end

  @spec input(atom(), atom()) :: {binary(), binary(), binary()}
  def input(:text, key) do
    {label(key), ~s(<%= text_input f, #{inspect_key(key)} %>), error(key)}
  end
  def input(:password, key) do
    {label(key), ~s(<%= password_input f, #{inspect_key(key)} %>), error(key)}
  end

  defp label(key) do
    ~s(<%= label f, #{inspect_key(key)} %>)
  end

  defp error(key) do
    ~s(<%= error_tag f, #{inspect_key(key)} %>)
  end

  defp inspect_key({:changeset, :pow_user_id_field}), do: "@changeset.data.__struct__.pow_user_id_field()"
  defp inspect_key(key), do: inspect(key)
end
