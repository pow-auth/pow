defmodule Pow.Phoenix.SessionHTML do
  @moduledoc false
  use Pow.Phoenix.Template

  # Credo will complain about unless statement but we want this first
  # credo:disable-for-next-line
  unless Pow.dependency_vsn_match?(:phoenix, "< 1.7.0") do
  template :new, :html,
  """
  <div class="mx-auto max-w-sm">
    <.header class="text-center">
      Sign in
      <:subtitle>
        Don't have an account?
        <.link navigate={<%= __inline_route__(Pow.Phoenix.RegistrationController, :new) %>} class="font-semibold text-brand hover:underline">
          Register
        </.link> now.
      </:subtitle>
    </.header>

    <.simple_form :let={f} for={<%= "@changeset" %>} as={:user} action={<%= "@action" %>} phx-update="ignore">
      <.error :if={<%= "@changeset.action" %>}>Oops, something went wrong! Please check the errors below.</.error>
      <.input field={<%= "f[\#{__user_id_field__("@changeset", :key)}]" %>} type={<%= __user_id_field__("@changeset", :type) %>} label={<%= __user_id_field__("@changeset", :label) %>} required />
      <.input field={<%= "f[:password]" %>} type="password" label="Password" value={nil} required />

      <:actions :let={f} :if={Pow.Plug.extension_enabled?(@conn, PowPersistentSession) || Pow.Plug.extension_enabled?(@conn, PowResetPassword)}>
        <.input :if={Pow.Plug.extension_enabled?(@conn, PowPersistentSession)} field={f[:persistent_session]} type="checkbox" label="Keep me logged in" />
        <.link :if={Pow.Plug.extension_enabled?(@conn, PowResetPassword)} href={<%= __inline_route__(PowResetPassword.Phoenix.ResetPasswordController, :new) %>} class="text-sm font-semibold">
          Forgot your password?
        </.link>
      </:actions>

      <:actions>
        <.button phx-disable-with="Signing in..." class="w-full">
          Sign in <span aria-hidden="true">→</span>
        </.button>
      </:actions>
    </.simple_form>
  </div>
  """
  else
  # TODO: Remove when Phoenix 1.7 required
  template :new, :html,
  """
  <h1>Sign in</h1>
  <%= render_form([
    {:text, {:changeset, :pow_user_id_field}},
    {:password, :password}
  ],
  button_label: "Sign in") %>

  <span><%%= link "Register", to: <%= __inline_route__(Pow.Phoenix.RegistrationController, :new) %> %></span>
  """
  end
end
