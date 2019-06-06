# PowLasLogin

This extension adds the ability to track when and from which IP address a user logged in.

You can then add to your templates a message such as:

```elixir
You last logged in <%= Timex.format!(@conn.assigns.current_user.last_login_at, "{relative}", :relative) %> from <%= @conn.assigns.current_user.last_login_from %>.
```

Time formatting courtesy of [timex](https://github.com/bitwalker/timex), thanks ;)

## Installation

Follow the instructions for extensions in [README.md](../../../README.md), and set `PowLastLogin` in the `:extensions` list.
