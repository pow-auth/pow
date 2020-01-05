# Changelog

## v1.0.16 (TBA)

### Enhancements

* [`PowPersistentSession.Plug.Cookie`] Now supports `:persistent_session_cookie_opts` to customize any options that will be passed on to `Plug.Conn.put_resp_cookie/4`
* [`PowResetPassword.Phoenix.ResetPasswordController`] Now uses `PowResetPassword.Phoenix.Messages.maybe_email_has_been_sent/1` with a generic response that tells the user the email has been sent only if an account was found
* [`PowResetPassword.Phoenix.ResetPasswordController`] When a user doesn't exist will now return success message if `PowEmailConfirmation` extension is enabled
* [`PowResetPassword.Phoenix.Messages`] Added `PowResetPassword.Phoenix.Messages.maybe_email_has_been_sent/1` and let `PowResetPassword.Phoenix.Messages.email_has_been_sent/1` fall back to it
* [`PowEmailConfirmation.Phoenix.ControllerCallbacks`] When a user tries to sign up and the email has already been taken the default e-mail confirmation required message will be shown

### Bug fixes

* [`Pow.Ecto.Schema.Changeset`] Fixed bug where `Pow.Ecto.Schema.Changeset.user_id_field_changeset/3` update with `nil` value caused an exception to be raised
* [`PowPersistentSession.Plug.Cookie`] Now expires the cookie 10 seconds after the last request when authenticating to prevent multiple simultaneous requests deletes the cookie immediately

### Documentation

* Added mailer rate limitation section to [production checklist guide](guides/production_checklist.md)
* [`Pow.Plug.Session`] Added section on session expiration to the docs
* Updated instructions in [umbrella project guide](guides/umbrella_project.md) to Elixir 1.9
* [`Pow.Store.Backend.Base`] Updated usage example with Cachex
* Added [security practices page](guides/security_practices.md)

## v1.0.15 (2019-11-20)

### Enhancements

* [`Pow.Extension.Base`] Extensions are now expected to have a base module with compile-time information whether certain modules are available to prevent unnecessary `Code.ensure_compiled?/1` calls:
  * Added `Pow.Extension.Base` module
  * Added `PowEmailConfirmation` module
  * Added `PowInvitation` module
  * Added `PowPersistentSession` module
  * Added `PowResetPassword` module
* [`PowPersistentSession.Plug.Cookie`] Added support for custom metadata:
  * `PowPersistentSession.Plug.Cookie.create/3` now stores a metadata keyword list that can be populated
  * `PowPersistentSession.Plug.Cookie.create/3` will now, instead of adding `:session_fingerprint` to the metadata, populate the `:session_metadata` keyword list with `:fingerprint`
  * `PowPersistentSession.Plug.Cookie.authenticate/2` will now populate session metadata with what exists in `:session_metadata` key for the persistent session metadata
  * `PowPersistentSession.Plug.Cookie.create/3` now ensures to delete the previous persistent session first, if one is found in cookies
* [`Pow.Extension.Config`] Added `Pow.Extension.Config.extension_modules/2`

### Bug fixes

* [`Router.Phoenix.Router`] Fixed bug where resource routes were not filtered correctly according to the path bindings

### Deprecations

* [`Pow.Extension.Config`] Deprecated `Pow.Extension.Config.discover_modules/2`

## v1.0.14 (2019-10-29)

### Changes

* Changed minmum password length to 8 (OWASP/NIST recommendations)
* `Pow.Phoenix.Router` now only filters routes that has equal number of bindings
* `Pow.Phoenix.Routes.user_not_authenticated_path/1` now only puts the `:request_path` param if the request is using "GET" method
* The stores has been refactored so the command conforms with ETS store. This means that put commands now accept `{key, value}` record element(s), and keys may be list for easier lookup.
  * `Pow.Store.Backend.Base` behaviour now requires to;
    * Accept `Pow.Store.Backend.Base.record/0` values for `put/2`
    * Accept `Pow.Store.Backend.Base.key/0` for `delete/2` and `get/2`
    * Implement `all/2`
    * Remove `keys/1`
    * Remove `put/3`
  * `Pow.Store.Backend.EtsCache` now uses `:ordered_set` instead of `:set` for efficiency
  * `Pow.Store.Backend.MnesiaCache` now uses `:ordered_set` instead of `:set` for efficiency
  * `Pow.Store.Backend.MnesiaCache` will delete all binary key records when initialized
  * `Pow.Store.Base` behaviour now requires to;
    * Accept erlang term value for keys in all methods
    * Implement `put/3` instead of `put/4`
    * Implement `delete/2` instead of `put/3`
    * Implement `get/2` instead of `put/3`
    * Remove `keys/2`
  * `Pow.Store.Base.all/3` added
  * `Pow.Store.Base.put/3` added
  * `Pow.Store.Base` will use binary key rather than key list if `all/2` doesn't exist in the backend cache
  * Added `Pow.Store.CredentialsCache.users/2`
  * Added `Pow.Store.CredentialsCache.sessions/2`
  * `Pow.Store.CredentialsCache` now adds a session key rather than appending to a list for the user key to prevent race condition
* `Pow.Plug.Session.create/3` now stores a keyword list with metadata for the session rather than just a timestamp
* `Pow.Plug.Session.fetch/2` and `Pow.Plug.Session.create/3` now assigns `:pow_session_metadata` in `conn.private` with the session metadata
* `Pow.Plug.Session.create/3` will use the metadata found in `conn.private[:pow_session_metadata]` if it exists and otherwise add a randomly unique id for `:fingerprint`
* `PowPersistentSession.Plug.Cookie.create/3` will use the value of `conn.private[:pow_session_metadata][:fingerprint]` if it exists as `:session_fingerprint` in the persistent session metadata
* `PowPersistentSession.Plug.Cookie.authenticate/2` will assign `:fingerprint` to `conn.private[:pow_session_metadata]` if it exists in the persistent session metadata
* `Pow.Store.CredentialsCache.put/3` will invalidate any other sessions with the same `:fingerprint` if any is set in session metadata
* `PowResetPassword.Phoenix.ResetPasswordController.create/2` when a user doesn't exist will now only return success message if the registration routes has been disabled, otherwise the form with an error message will be returned
* Added `PowResetPassword.Phoenix.Messages.user_not_found/1`

### Bug fixes

* Fixed bug where `Pow.Store.CredentialsCache` wasn't used due to how `Pow.Store.Base` macro worked
* Fixed bug where `PowEmailConfirmation.Phoenix.ControllerCallbacks` couldn't deliver email

### Deprecations

* Deprecated `Pow.Store.Backend.EtsCache.keys/1`
* Deprecated `Pow.Store.Backend.EtsCache.put/3`
* Deprecated `Pow.Store.Backend.MnesiaCache.keys/1`
* Deprecated `Pow.Store.Backend.MnesiaCache.put/3`
* Deprecated `Pow.Store.Base.keys/2`
* Deprecated `Pow.Store.Base.put/4`
* Deprecated `Pow.Store.CredentialsCache.user_session_keys/3`
* Deprecated `Pow.Store.CredentialsCache.sessions/3`

## v1.0.13 (2019-08-25)

* Updated `PowEmailConfirmation.Ecto.Schema.changeset/3` so;
  * when `:email` is identical to `:unconfirmed_email` it won't generate new `:email_confirmation_token`
  * when `:email` is identical to the persisted `:email` value both `:email_confirmation_token` and `:unconfirmed_email` will be set to `nil`
  * when there is no `:email` value in the params nothing happens
* Updated `PowEmailConfirmation.Ecto.Schema.confirm_email_changeset/1` so now `:email_confirmation_token` is set to `nil`
* Updated `Pow.Ecto.Schema.Changeset.user_id_field_changeset/3` so the e-mail validator now accepts unicode e-mails
* Added `PowEmailConfirmation.Ecto.Context.current_email_unconfirmed?/2` and `PowEmailConfirmation.Plug.pending_email_change?/1`
* Added `:email_validator` configuration option to `Pow.Ecto.Schema.Changeset`
* Added `Pow.Ecto.Schema.Changeset.validate_email/1`
* Fixed bug in `PowEmailConfirmation.Phoenix.ControllerCallbacks.send_confirmation_email/2` where the confirmation e-mail wasn't send to the updated e-mail address

## v1.0.12 (2019-08-16)

* Added API integration guide
* Added `:reset_password_token_store` configuration setting
* To prevent timing attacks, `Pow.Ecto.Context.authenticate/2` now verifies password on a blank user struct when no user can be found for the provided user id, but will always return nil. The blank user struct has a nil `:password_hash` value. The struct will be passed along with a blank password to the `verify_password/2` method in the user schema module.
* To prevent timing attacks, when `Pow.Ecto.Schema.Changeset.verify_password/3` receives a struct with a nil `:password_hash` value, it'll hash a blank password, but always return false.
* To prevent timing attacks, the UUID is always generated in `PowResetPassword.Plug.create_reset_token/2` whether the user exists or not.
* `PowPersistentSession.Plug.Base` now accepts `:persistent_session_ttl` which will pass the TTL to the cache backend and used for the max age of the sesion cookie in `PowPersistentSession.Plug.Cookie`
* Deprecated `:persistent_session_cookie_max_age` configuration setting
* `Pow.Store.Backend.MnesiaCache` can now auto join clusters
* `Pow.Store.Backend.MnesiaCache.Unsplit` module added for self-healing after network split
* Removed `:nodes` config option for `Pow.Store.Backend.MnesiaCache`

## v1.0.11 (2019-06-13)

* Fixed bug in router filters with Phoenix 1.4.7

## v1.0.10 (2019-06-09)

* Prevent browser cache of `Pow.Phoenix.SessionController.new/2`, `Pow.Phoenix.RegistrationController.new/2` and `PowInvitation.Phoenix.InvitationController.edit/2` by setting "Cache-Control" header unless it already has been customized
* All links in docs generated with `mix docs` and on [hexdocs.pm](http://hexdocs.pm/pow/) now works
* Generated docs now uses lower case file name except for `README`, `CONTRIBUTING` and `CHANGELOG`
* Removed duplicate call for `Pow.Plug.Session.delete/2` in `Pow.Plug.Sesssion.create/3`

## v1.0.9 (2019-06-04)

### Changes

* `Pow.Phoenix.Router` will now only add specific routes if there is no matching route already defined
* Added `Pow.Plug.get_plug/1` and instead of `:mod`, `:plug` is used in config
* `Pow.Ecto.Context.authenticate/2` now returns nil if user id or password is nil

### Bug fixes

* Fixed bug with exception raised in `Pow.Ecto.Schema.normalize_user_id_field_value/1` when calling `Pow.Ecto.Context.get_by/2` with a non binary user id
* Fixed bug with exception raised in `Pow.Ecto.Schema.normalize_user_id_field_value/1` when calling `Pow.Ecto.Context.authenticate/2` with a non binary user id

### Deprecations

* Deprecated `Pow.Plug.get_mod/1`
* Removed call to `Pow.Ecto.Context.repo/1`

## v1.0.8 (2019-05-24)

### Changes

* Added support for layout in mails with `Pow.Phoenix.Mailer.Mail` by setting `conn.private[:pow_mailer_layout]` same way as the Phoenix layout with `conn.private[:phoenix_layout]`
* Added `:prefix` repo opts support to use in multitenant apps
* Removed `@changeset.data.__struct__.pow_user_id_field()` in template in favor of using `Pow.Ecto.Schema.user_id_field/1`

### Bug fixes

* Fixed bug in `Pow.Ecto.Schema.Changeset.current_password_changeset/3` where an exception would be thrown if the virtual `:current_password` field of the user struct was set and either the `:current_password` change was blank or identical

### Deprecations

* Deprecated `Mix.Pow.Ecto.Migration.create_migration_files/3` and moved it to `Mix.Pow.Ecto.Migration.create_migration_file/3`
* Deprecated `Pow.Ecto.Context.repo/1` and moved it to `Pow.Config.repo!/1`
* Deprecated `Pow.Ecto.Context.user_schema_mod/1` and moved it to `Pow.Config.user!/1`

## v1.0.7 (2019-05-01)

* Fixed bug with Phoenix 1.4.4 scoped routes

## v1.0.6 (2019-04-19)

* Fixed bug where custom layout setting raised exception in `Pow.Phoenix.ViewHelpers.layout/1`
* Prevent users from changing their email to one already taken when the PowEmailConfirmation extension has been enabled

## v1.0.5 (2019-04-09)

* Added `extension_messages/1` to extension controllers and callbacks
* Improved feedback for when no templates are generated for an extension with `mix pow.extension.phoenix.gen.templates` and `mix pow.extension.phoenix.mailer.gen.templates` tasks
* Error flash is no longer overridden in `Pow.Phoenix.PlugErrorHandler` if the error message is nil
* Fixed bug in the migration generator where `references/2` wasn't called with options
* Support any `:plug` version below `2.0.0`
* Deprecated `Pow.Extension.Ecto.Context.Base`

## v1.0.4 (2019-03-13)

* Added `PowInvitation` to the `mix pow.extension.phoenix.gen.templates` and `mix pow.extension.phoenix.mailer.gen.templates` tasks
* Fixed issue in umbrella projects where extensions wasn't found in environment configuration
* Fixed so `:namespace` environment config can be used as web app module name
* Shell instructions will only be printed if the configuration is missing
* Now requires that `:ecto` or `:phoenix` are included in the dependency list for the app to run respective mix tasks
* Deprecated `Mix.Pow.context_app/0`
* Deprecated `Mix.Pow.ensure_dep!/3`
* Deprecated `Mix.Pow.context_base/1`

## v1.0.3 (2019-03-09)

### Changes

* Added `PowInvitation` extension
* Added support in `Pow.Ecto.Schema` for Ecto associations fields
* Added support for adding custom methods with `Pow.Extension.Ecto.Schema` through `__using__/1` macro in extension ecto schema module
* Help information raised with invalid schema arguments for `pow.install`, `pow.ecto.install`, `pow.ecto.gen.migration`, and `pow.ecto.gen.schema` mix tasks
* `PowEmailConfirmation` now redirects unconfirmed users to `after_registration_path/1` or `after_sign_in_path/1` rather than `pow_session_path(conn, :new)`

### Bug fixes

* Correct shell instructions for `mix pow.install` task with custom schema
* Fixed bug in `Pow.Extension.Phoenix.Router.Base` and `Pow.Extension.Phoenix.Messages` where the full extension name wasn't used to namespace methods

### Deprecations

* Deprecated `Pow.Extension.Config.underscore_extension/1`
* Deprecated `PowResetPassword.Ecto.Context.password_changeset/2`
* Deprecated `Pow.Ecto.Schema.filter_new_fields/2`
* Deprecated `:messages_backend_fallback` setting for extension controllers
* Removed deprecated macro `router_helpers/1` in `Pow.Phoenix.Controller`

## v1.0.2 (2019-02-28)

* Added flash error message about e-mail confirmation for when user changes e-mail with PowEmailConfirmation enabled
* Added `new_password_changeset/3` and `confirm_password_changeset/3` to `Pow.Ecto.Schema.Changeset`
* Redis cache store backend guide
* Correct shell instructions for `mix pow.phoenix.gen.templates` task
* Only load environment config in `Pow.Config.get/3` when no key is set in the provided config
* Fixed issue in `Pow.Store.Backend.MnesiaCache.keys/1` and `Pow.Store.Backend.EtsCache.keys/1` so they now return keys without namespace
* `Pow.Store.Backend.MnesiaCache.put/3` now raises an error if TTL is not provided

### Breaking changes

* `PowResetPassword.Plug.reset_password_token/1` has been removed

## v1.0.1 (2019-01-27)

* `pow.extension.ecto.gen.migrations` mix task will output warning when a migration file won't be generated for any particular extension
* Leading and trailing whitespace is removed from the user id field value (in addition to forced lower case)
* An exception is raised when `pow_routes/0` or `pow_extension_routes/0` are used inside router scopes with aliases
* Mail view templates assigns now has `[user: user, conn: conn]` along with the template specific assigns
* Mail view subject methods now gets the same assigns passed as mail view template assigns instead of only `[conn: conn]`
* Added `pow_registration_routes/0`, `pow_session_routes/0` and `pow_scope/1` macros to the router module
* Added guide on how to disable registration

## v1.0.0 (2018-11-18)

* Phoenix 1.4 support
* Ecto 3.0 support
