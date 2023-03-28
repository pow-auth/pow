# Disable registration

You may have an app in which users are not permitted to sign up. Pow makes it easy to disable registration by removing the registration routes.

First you should follow the [Modify templates](../README.md#modify-templates) section in README.

## Templates

Open up `WEB_PATH/controllers/pow/session_html/new.html.heex` and remove the registration link. Delete the `WEB_PATH/controllers/pow/registration_html/new.html.heex` file.

## Routes

Replace `pow_routes()` with `pow_session_routes()` in your router module.

Add the following routes below to enable account updates and deletion:

```elixir
scope "/", Pow.Phoenix, as: "pow" do
  pipe_through [:browser, :protected]
  resources "/registration", RegistrationController, singleton: true, only: [:edit, :update, :delete]
end
```

That's it!
