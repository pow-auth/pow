# PowResetPassword

This extension will allow users to reset the password by sending an e-mail with a reset password link. It requires that the user schema has an `:email` field.

A success message will always be returned during reset request if registration routes has been disabled to prevent information leak.

## Installation

Follow the instructions for extensions in [README.md](../../../README.md#add-extensions-support), and set `PowResetPassword` in the `:extensions` list.

## Configuration

Add the following link to your `WEB_PATH/templates/pow/session/new.html.eex` template (you may need to generate the templates first):

```elixir
link("Reset password", to: Routes.pow_reset_password_reset_password_path(@conn, :new))
```
