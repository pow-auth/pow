defmodule Pow.Phoenix.HTML.FormTemplateTest do
  use ExUnit.Case
  doctest Pow.Phoenix.HTML.FormTemplate

  alias Pow.Phoenix.HTML.FormTemplate

  test "render/2 with minimalist" do
    html = FormTemplate.render([
      {:text, {:changeset, :pow_user_id_field}},
      {:password, :password},
      {:password, :password_confirmation}
    ])

    refute html =~ "<div class=\"form-group\">"
    assert html =~ "<%= label f, Pow.Ecto.Schema.user_id_field(@changeset) %>"
    assert html =~ "<%= text_input f, Pow.Ecto.Schema.user_id_field(@changeset) %>"
    assert html =~ "<%= error_tag f, Pow.Ecto.Schema.user_id_field(@changeset) %>"
    assert html =~ "<%= label f, :password %>"
    assert html =~ "<%= password_input f, :password %>"
    assert html =~ "<%= error_tag f, :password %>"
  end

  test "render/2 with bootstrap" do
    html = FormTemplate.render([
      {:text, {:changeset, :pow_user_id_field}},
      {:password, :password},
      {:password, :password_confirmation}
    ], bootstrap: true)

    assert html =~ "<div class=\"form-group\">"
    assert html =~ "<%= label f, Pow.Ecto.Schema.user_id_field(@changeset), class: \"control-label\" %>"
    assert html =~ "<%= text_input f, Pow.Ecto.Schema.user_id_field(@changeset), class: \"form-control\" %>"
    assert html =~ "<%= error_tag f, Pow.Ecto.Schema.user_id_field(@changeset) %>"
    assert html =~ "<%= label f, :password, class: \"control-label\" %>"
    assert html =~ "<%= password_input f, :password, class: \"form-control\" %>"
    assert html =~ "<%= error_tag f, :password %>"
  end
end
