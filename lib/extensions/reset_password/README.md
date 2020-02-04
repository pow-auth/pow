# PowResetPassword

This extension will allow users to reset the password by sending an e-mail with a reset password link. It requires that the user schema has an `:email` field.

To prevent user enumeration attacks, the generic `PowResetPassword.Phoenix.Messages.maybe_email_has_been_sent/1` message is always shown when requesting password reset. If `pow_prevent_user_enumeration: false` is set in `conn.private` the form will be shown instead with the `PowResetPassword.Phoenix.Messages.user_not_found/1` message.

## Installation

Follow the instructions for extensions in [README.md](../../../README.md#add-extensions-support), and set `PowResetPassword` in the `:extensions` list.

## Configuration

Add the following link to your `WEB_PATH/templates/pow/session/new.html.eex` template (you may need to generate the templates first):

```elixir
link("Reset password", to: Routes.pow_reset_password_reset_password_path(@conn, :new))
```
