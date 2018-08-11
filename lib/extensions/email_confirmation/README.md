# PowEmailConfirmation

This extension will send an e-mail confirmation link when the user registers, and when the user changes their e-mail. It requires that the user schema has an `:email` field.

Users won't be signed in when they register, and can't sign in until the e-mail has been confirmed. The confirmation e-mail will be sent every time the sign in fails. When users are already registered, the e-mail won't be changed for a user until the user has clicked the e-mail confirmation link.

## Installation

Follow the instructions for extensions in [README.md](../../../README.md), and set `PowEmailConfirmation` in the `:extensions` list.

## Configuration

Add the following section to your `WEB_PATH/templates/pow/registration/edit.html.eex` template (you may need to generate the templates first) after the e-mail field:

```elixir
<%= if @changeset.data.unconfirmed_email do %>
  <div>
    <p>Click the link in the confirmation email to change your email to <%= @changeset.data.unconfirmed_email %></span>.</p>
  </div>
<% end %>
```

## Prevent persistent session sign in

To prevent the persistent session from being created when the email hasn't been confirmed, `PowEmailConfirmation` should be placed first in the extensions list. It'll halt the connection.