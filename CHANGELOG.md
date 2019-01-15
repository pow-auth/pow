# Changelog

## v1.0.1 (TBA)

* `pow.extension.ecto.gen.migrations` mix task will output warning when a migration file won't be generated for any particular extension
* Leading and trailing whitespace is removed from the user id field value (in addition to forced lower case)
* An exception is raised when `pow_routes/0` or `pow_extension_routes/0` are used inside router scopes with aliases

## v1.0.0 (2018-11-18)

* Phoenix 1.4 support
* Ecto 3.0 support