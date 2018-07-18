
  defmodule Authex.Phoenix.HTML.FormTemplate do
    @template EEx.compile_string """
  <%%= Phoenix.HTML.Form.form_for @changeset, @action, fn f -> %>
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
      <%%= Phoenix.HTML.Form.submit <%= inspect button_label %> %>
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
      {label(key), ~s(<%= Phoenix.HTML.Form.text_input f, #{inspect_key(key)} %>), error(key)}
    end
    def input(:password, key) do
      {label(key), ~s(<%= Phoenix.HTML.Form.password_input f, #{inspect_key(key)} %>), error(key)}
    end

    defp label(key) do
      ~s(<%= Phoenix.HTML.Form.label f, #{inspect_key(key)} %>)
    end

    defp error(key) do
      ~s(<%= Authex.Phoenix.HTML.ErrorHelpers.error_tag f, #{inspect_key(key)} %>)
    end

    defp inspect_key({:module_attribute, key}), do: "Authex.Phoenix.ViewHelpers.module_attribute(@changeset, #{inspect(key)})"
    defp inspect_key(key), do: inspect(key)
end
