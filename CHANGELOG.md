# Changelog

## v1.1.0 (TBA)

### Changes

- Requires Elixir 1.7 or higher
- Requires Ecto 3.0 or higher
- Requires Phoenix 1.4.7 or higher

### Deprecations

- Removed deprecated method `PowResetPassword.Ecto.Context.password_changeset/2`
- Removed deprecated method `Pow.Extension.Config.underscore_extension/1`
- Removed deprecated method `Mix.Pow.context_app/0`
- Removed deprecated method `Mix.Pow.ensure_dep!/3`
- Removed deprecated method `Mix.Pow.context_base/1`
- Removed deprecated method `Mix.Pow.Ecto.Migration.create_migration_files/3`
- Removed deprecated method `Pow.Ecto.Context.repo/1`
- Removed deprecated method `Pow.Ecto.Context.user_schema_mod/1`
- Removed deprecated method `Pow.Plug.get_mod/1`
- Removed deprecated method `Pow.Plug.clear_authenticated_user/1`
- Removed deprecated method `Pow.Store.Backend.EtsCache.put/3`
- Removed deprecated method `Pow.Store.Backend.EtsCache.keys/1`
- Removed deprecated method `Pow.Store.Backend.MnesiaCache.put/3`
- Removed deprecated method `Pow.Store.Backend.MnesiaCache.keys/1`
- Removed deprecated method `Pow.Store.Base.keys/2`
- Removed deprecated method `Pow.Store.Base.put/4`
- Removed deprecated method `Pow.Store.CredentialsCache.sessions/3`
- Removed deprecated method `Pow.Store.CredentialsCache.user_session_keys/3`
- Removed deprecated method `Pow.Extension.Config.discover_modules/2`
- Removed deprecated method `PowEmailConfirmation.Ecto.Context.confirm_email/2`
- Removed deprecated method `PowEmailConfirmation.Ecto.Schema.confirm_email_changeset/1`
- Removed deprecated method `PowEmailConfirmation.Plug.confirm_email/2`
- Removed deprecated method `PowInvitation.Plug.invited_user_from_token/2`
- Removed deprecated method `PowInvitation.Plug.assign_invited_user/2`
- Removed deprecated method `PowResetPassword.Plug.assign_reset_password_user/2`
- Removed deprecated method `PowResetPassword.Plug.user_from_token/2`
- Removed deprecated `:session_store` configuration option for `Pow.Plug.Base`, `:credentials_cache_store` is used instead
- Removed deprecated `:messages_backend_fallback` configuration option for `Pow.Extension.Phoenix.Controller.Base`
- Removed deprecated `:persistent_session_cookie_max_age` configuration option for `PowPersistentSession.Plug.Cookie`
- Removed deprecated `:nodes` configuration option for `Pow.Store.Backend.MnesiaCache`
- Removed backwards compatibility in `Pow.Phoenix.Router` for routes generated with Phoenix `<= 1.4.6`
- Removed deprecated Bootstrap support in `Pow.Phoenix.HTML.FormTemplate`
- Removed deprecated module `Pow.Extension.Ecto.Context.Base`
- `Pow.Plug.Base` no longer sets `:mod` in the `:pow_config` private plug key
- `Pow.Plug.Session` no longer has backwards compatibility with `<= 1.0.13` session values
- `Pow.Store.Base` no longer has backwards compability with binary key cache backends
- `PowPersistentSession.Plug.Cookie` no longer has backwards compatibility with `<= 1.0.14` session values or `:session_fingerprint` metadata
- `Pow.Store.Base` macro no longer adds or supports overriding the following methods:
  - `put/4`
  - `delete/3`
  - `get/3`
- `Pow.Store.Backend.MnesiaCache` no longer removes old deprecated records
- `Pow.Store.CredentialsCache` no longer handles deletion of deprecated records
- `Pow.Ecto.Schema.Changeset.confirm_password_changeset/3` no longer handles `:confirm_password` param
- `Pow.Extension.Base` no longer handles dynamic lookup, a base module is now required for all extensions
- `PowEmailConfirmation.Plug.confirm_email/2` no longer accepts binary (token) as second argument
