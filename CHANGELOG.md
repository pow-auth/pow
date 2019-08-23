# Changelog

## v1.0.13 (TBA)

* Updated `PowEmailConfirmation.Ecto.Schema.changeset/3` so;
  * when `:email` is identical to `:unconfirmed_email` it won't generate new `:email_confirmation_token`
  * when `:email` is identical to the persisted `:email` value both `:email_confirmation_token` and `:unconfirmed_email` will be set to `nil`
  * when there is no `:email` value in the params nothing happens
* Updated `PowEmailConfirmation.Ecto.Schema.confirm_email_changeset/1` so now `:email_confirmation_token` is set to `nil`
* Fixed bug in `PowEmailConfirmation.Phoenix.ControllerCallbacks.send_confirmation_email/2` where the confirmation e-mail wasn't send to the updated e-mail address
* Added `PowEmailConfirmation.Ecto.Context.current_email_unconfirmed?/2` and `PowEmailConfirmation.Plug.pending_email_change?/1`

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
