# Pow in an umbrella project

Adding Pow to an umbrella project is near identical to a single app setup.

Instead of running `mix pow.install`, you should run `mix pow.ecto.install` inside your ecto app, and `mix pow.phoenix.install` inside your phoenix app(s).

You can follow the rest of the [README](../README.md#phoenix-app) instructions with the following caveats in mind:

- Run all mix ecto tasks inside the ecto app
- Run all mix phoenix tasks inside the phoenix app(s)
- For a project generated with `mix phx.new --umbrella` use `:my_app_web` instead of `:my_app`
