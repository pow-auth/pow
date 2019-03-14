# Disable registration

You may have an app in which users are not permitted to sign up. Pow makes it easy to disable registration by removing the registration routes.

First you should follow the [Modify templates](../README.md#modify-templates) section in README.

## Templates

Open up `templates/pow/session/new.html.eex` and remove the `Routes.pow_registration_path/2` link. Delete the `templates/pow/registration/new.html.eex` file.

## Routes

Replace `pow_routes()` with `pow_session_routes()` in your router module.

Add the following routes below to enable account updates and deletion:

```elixir
scope "/", Pow.Phoenix, as: "pow" do
  resources "/registration", RegistrationController, singleton: true, only: [:edit, :update, :delete]
end
```

That's it!