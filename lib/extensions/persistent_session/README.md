# PowPersistentSession

This extension can reissue sessions by setting a cookie with a token that may be used exactly once to issue the session. The cookie and token will expire after 30 days. Once the session has been issued, a new cookie and token will be set that expires after another 30 days.

## Installation

Follow the instructions for extensions in [README.md](../../../README.md#add-extensions-support), and set `PowPersistentSession` in the `:extensions` list.

Add the following plug after the pow session plug in your `WEB_PATH/endpoint.ex`:

```elixir
defmodule MyAppWeb.Endpoint do
  # ...

  plug Pow.Plug.Session, otp_app: :my_app
  plug PowPersistentSession.Plug.Cookie
  #...
end
```

## Configuration

By default, the persistent session is automatically used if the extension has been enabled. If you wish to let the user manage this, you should add the following checkbox to the form in `WEB_PATH/templates/pow/session/new.html.eex` (you may need to generate the templates first):

```elixir
<%= label f, :persistent_session, "Remember me" %>
<%= checkbox f, :persistent_session %>
```
