defmodule PowInvitation.Phoenix.InvitationHTML do
  @moduledoc false
  use Pow.Phoenix.Template

  # Credo will complain about unless statement but we want this first
  # credo:disable-for-next-line
  unless Pow.dependency_vsn_match?(:phoenix, "< 1.7.0") do
  template :new, :html,
  """
  <div class="mx-auto max-w-sm">
    <.header class="text-center">
      Invite
    </.header>

    <.simple_form :let={f} for={<%= "@changeset" %>} as={:user} action={<%= "@action" %>} phx-update="ignore">
      <.error :if={<%= "@changeset.action" %>}>Oops, something went wrong! Please check the errors below.</.error>
      <.input field={<%= "f[\#{__user_id_field__("@changeset", :key)}]" %>} type={<%= __user_id_field__("@changeset", :type) %>} label={<%= __user_id_field__("@changeset", :label) %>} required />

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
        <.button phx-disable-with="Submitting..." class="w-full">
          Submit <span aria-hidden="true">→</span>
        </.button>
      </:actions>
    </.simple_form>
  </div>
  """

  template :show, :html,
  """
  <div class="mx-auto max-w-sm">
    <.header class="text-center">
      Invitation URL
      <:subtitle>
        Please send the following URL to the invitee.
      </:subtitle>
    </.header>

    <div class="space-y-8 bg-white mt-10">
      <div class="flex items-center gap-1 text-sm leading-6 text-zinc-600">
        <.input name="invite-url" type="text" id="invite-url" value={<%= "@url" %>} class="mt-0" readonly />
        <.button phx-click={JS.dispatch("phx:share", to: "#invite-url")} aria-label={"Share"} class="mt-2">
          <.icon name="hero-arrow-up-on-square" class="w-6 h-6" />
        </.button>
      </div>
    </div>
  </div>
  <script type="text/javascript">
    window.addEventListener("phx:share", (event) => {
      let url = event.target.value;

      navigator.clipboard.writeText(url).then(
        () => {
          /* clipboard successfully set */
        },
        () => {
          /* clipboard write failed */
        });

      navigator.share({url: url}).then(
        () => {
          /* share succeeded */
        },
        () => {
          /* share failed */
        });
    })
  </script>
  """
  else
  # TODO: Remove when Phoenix 1.7 required
  template :new, :html,
  """
  <h1>Invite</h1>

  <%= render_form([
    {:text, {:changeset, :pow_user_id_field}}
  ]) %>
  """

  template :edit, :html,
  """
  <h1>Register</h1>

  <%= render_form([
    {:text, {:changeset, :pow_user_id_field}},
    {:password, :password},
    {:password, :password_confirmation}
  ]) %>

  <span><%%= link "Sign in", to: <%= __inline_route__(Pow.Phoenix.SessionController, :new) %> %></span>
  """

  template :show, :html,
  """
  <h1>Invitation</h1>

  <blockquote><%%= @url %></blockquote>
  """
  end
end
