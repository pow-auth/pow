
  defmodule Authex.Phoenix.HTML.Template do
    @form_template EEx.compile_string """
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
      <%%= Phoenix.HTML.Form.submit "Submit" %>
    </div>
  <%% end %>
  """

    @spec template(:form, atom(), atom()) :: Macro.t()
    def template(:form, controller, action) do
      inputs = inputs(controller, action)

      unquote(@form_template)
    end

    defp inputs(:session, :new) do
      [
        input(:text, {:module_attribute, :login_field}),
        input(:password, :password)
      ]
    end
    defp inputs(:registration, :new) do
      [
        input(:text, {:module_attribute, :login_field}),
        input(:password, :password),
        input(:password, :password_confirm)
      ]
    end
    defp inputs(:registration, :edit) do
      input(:password, :current_password)
      |> List.wrap()
      |> Enum.concat(inputs(:registration, :new))
    end


    defp input(:text, key) do
      {label(key), ~s(<%= Phoenix.HTML.Form.text_input f, #{inspect_key(key)} %>), error(key)}
    end

    defp input(:password, key) do
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
