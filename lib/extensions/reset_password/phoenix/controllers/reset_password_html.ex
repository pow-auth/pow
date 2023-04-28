defmodule PowResetPassword.Phoenix.ResetPasswordHTML do
  @moduledoc false
  use Pow.Phoenix.Template

  # Credo will complain about unless statement but we want this first
  # credo:disable-for-next-line
  unless Pow.dependency_vsn_match?(:phoenix, "< 1.7.0") do
  template :new, :html,
  """
  <div class="mx-auto max-w-sm">
    <.header class="text-center">
      Reset password
      <:subtitle>
        Know your password?
        <.link navigate={<%= __inline_route__(Pow.Phoenix.SessionController, :new) %>} class="font-semibold text-brand hover:underline">
          Sign in
        </.link> now.
      </:subtitle>
    </.header>

    <.simple_form :let={f} for={<%= "@changeset" %>} as={:user} action={<%= "@action" %>} phx-update="ignore">
      <.error :if={<%= "@changeset.action" %>}>Oops, something went wrong! Please check the errors below.</.error>
      <.input field={<%= "f[:email]" %>} type="email" label="Email" required />

      <:actions>
        <.button phx-disable-with="Submitting..." class="w-full">
          Submit <span aria-hidden="true">→</span>
        </.button>
      </:actions>
    </.simple_form>
  </div>
  """

  template :edit, :html,
  """
  <div class="mx-auto max-w-sm">
    <.header class="text-center">
      Reset password
      <:subtitle>
        Know your password?
        <.link navigate={<%= __inline_route__(Pow.Phoenix.SessionController, :new) %>} class="font-semibold text-brand hover:underline">
          Sign in
        </.link> now.
      </:subtitle>
    </.header>

    <.simple_form :let={f} for={<%= "@changeset" %>} as={:user} action={<%= "@action" %>} phx-update="ignore">
      <.error :if={<%= "@changeset.action" %>}>Oops, something went wrong! Please check the errors below.</.error>
      <.input field={<%= "f[:password]" %>} type="password" label="New password" required />
      <.input field={<%= "f[:password_confirmation]" %>} type="password" label="Confirm new password" required />

      <:actions>
        <.button phx-disable-with="Submitting..." class="w-full">
          Submit <span aria-hidden="true">→</span>
        </.button>
      </:actions>
    </.simple_form>
  </div>
  """
  else
  # TODO: Remove when Phoenix 1.7 required
  template :new, :html,
  """
  <h1>Reset password</h1>

  <%= render_form([
    {:text, :email}
  ]) %>
  """

  template :edit, :html,
  """
  <h1>Reset password</h1>

  <%= render_form([
    {:password, :password},
    {:password, :password_confirmation}
  ]) %>

  <span><%%= link "Sign in", to: <%= __inline_route__(Pow.Phoenix.SessionController, :new) %> %></span>
  """
  end
end
