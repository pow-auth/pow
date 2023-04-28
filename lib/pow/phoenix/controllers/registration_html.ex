defmodule Pow.Phoenix.RegistrationHTML do
  @moduledoc false
  use Pow.Phoenix.Template

  # Credo will complain about unless statement but we want this first
  # credo:disable-for-next-line
  unless Pow.dependency_vsn_match?(:phoenix, "< 1.7.0") do
  template :new, :html,
  """
  <div class="mx-auto max-w-sm">
    <.header class="text-center">
      Register
      <:subtitle>
        Already have an account?
        <.link navigate={<%= __inline_route__(Pow.Phoenix.SessionController, :new) %>} class="font-semibold text-brand hover:underline">
          Sign in
        </.link> now.
      </:subtitle>
    </.header>

    <.simple_form :let={f} for={<%= "@changeset" %>} as={:user} action={<%= "@action" %>} phx-update="ignore">
      <.error :if={<%= "@changeset.action" %>}>Oops, something went wrong! Please check the errors below.</.error>
      <.input field={<%= "f[\#{__user_id_field__("@changeset", :key)}]" %>} type={<%= __user_id_field__("@changeset", :type) %>} label={<%= __user_id_field__("@changeset", :label) %>} required />
      <.input field={<%= "f[:password]" %>} type="password" label="Password" required />
      <.input field={<%= "f[:password_confirmation]" %>} type="password" label="Confirm password" required />

      <:actions>
        <.button phx-disable-with="Registering..." class="w-full">
          Register <span aria-hidden="true">→</span>
        </.button>
      </:actions>
    </.simple_form>
  </div>
  """

  template :edit, :html,
  """
  <div class="mx-auto max-w-sm">
    <.header class="text-center">
      Edit Account
    </.header>

    <.simple_form :let={f} for={<%= "@changeset" %>} as={:user} action={<%= "@action" %>} phx-update="ignore">
      <.error :if={Pow.Plug.extension_enabled?(@conn, PowResetPassword) && @changeset.data.unconfirmed_email}>
        <span>Click the link in the confirmation email to change your email to <span class="font-semibold"><%%= @changeset.data.unconfirmed_email %></span>.</span>
      </.error>
      <.error :if={<%= "@changeset.action" %>}>Oops, something went wrong! Please check the errors below.</.error>
      <.input field={<%= "f[:current_password]" %>} type="password" label="Current password" value={nil} required />
      <.input field={<%= "f[\#{__user_id_field__("@changeset", :key)}]" %>} type={<%= __user_id_field__("@changeset", :type) %>} label={<%= __user_id_field__("@changeset", :label) %>} required />
      <.input field={<%= "f[:password]" %>} type="password" label="New password" />
      <.input field={<%= "f[:password_confirmation]" %>} type="password" label="Confirm new password" />

      <:actions>
        <.button phx-disable-with="Updating..." class="w-full">
          Update <span aria-hidden="true">→</span>
        </.button>
      </:actions>
    </.simple_form>
  </div>
  """
  else
  # TODO: Remove when Phoenix 1.7 required
  template :new, :html,
  """
  <h1>Register</h1>

  <%= render_form([
    {:text, {:changeset, :pow_user_id_field}},
    {:password, :password},
    {:password, :password_confirmation}
  ],
  button_label: "Register") %>

  <span><%%= link "Sign in", to: <%= __inline_route__(Pow.Phoenix.SessionController, :new) %>%></span>
  """

  template :edit, :html,
  """
  <h1>Edit profile</h1>

  <%= render_form([
    {:password, :current_password},
    {:text, {:changeset, :pow_user_id_field}},
    {:password, :password},
    {:password, :password_confirmation}
  ],
  button_label: "Update") %>
  """
  end
end
