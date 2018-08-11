defmodule Pow.Phoenix.HTML.FormTemplate do
  @moduledoc """
  Module that can build user form templates for Phoenix.

  This module is build to support Phoenix 1.4 with minimalist CSS. Another
  module `Pow.Phoenix.HTML.Bootstrap` exists to ensure Phoenix 1.3 templates
  can be rendered with Bootstrap CSS classes. This is the default behaviour
  until Phoenix 1.4 is released.
  """
  alias Pow.Phoenix.HTML.Bootstrap

  @template EEx.compile_string """
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
  """

  @doc """
  Renders a form.

  ## Options

    * `:button_label` - the submit button label, defaults to "Submit".
    * `:bootstrap` - to render form as bootstrap, defaults to true.
  """
  @spec render(list(), Keyword.t()) :: Macro.t()
  def render(inputs, opts \\ []) do
    button_label = Keyword.get(opts, :button_label, "Submit")

    case Keyword.get(opts, :bootstrap, true) do
      true -> Bootstrap.render_form(inputs, button_label)
      _any -> render_form(inputs, button_label)
    end
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
  def inspect_key({:changeset, :pow_user_id_field}), do: "@changeset.data.__struct__.pow_user_id_field()"
  def inspect_key(key), do: inspect(key)
end
