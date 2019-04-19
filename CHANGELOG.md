# Changelog

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