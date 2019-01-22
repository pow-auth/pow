# Disable registration

You may have an app in which users are not permitted to sign up. Pow makes it easy to disable registration by removing the registration routes.

First you should follow the [Modify templates](../README.md#modify-templates) section in README.

## Templates

Delete the `templates/pow/registration` folder and the `views/pow/registration_view.ex` file. Open up `templates/pow/session/new.html.eex` and remove the `Routes.pow_registration_path` link.

## Routes

Replace `pow_routes()` with `pow_session_routes()` in your router module.

That's it!