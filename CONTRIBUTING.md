# Contributing to Pow

All contributions to Pow are welcome!

Postgres is required to test locally. The [test helper](test/test_helper.exs) will automatically set up the database for you when you run the tests. Run `mix credo` for static code analysing.

## Postgres setup

The test environment has minimal database configuration which means it'll by default use the current username in the OS. If no such role exists (common with older postgres setup where only `postgres` role exists), you can easily create the superuser user by running:

```bash
createuser -U postgres -s $(whoami)
```

## Mocks

As the default ETS cache store backend works asynchronously, a synchronous ETS cache store backend ([`Pow.Test.EtsCacheMock`](test/support/ets_cache_mock.ex)) is used instead.

Only Ecto modules are tested against the database. Plug and Phoenix modules uses [`Pow.Test.ContextMock`](test/support/context_mock.ex).

## Extension test support

Due to compile-time configuration of Phoenix modules and User schema modules, several modules are dynamically generated with [`Pow.Test.ExtensionMocks`](test/support/extensions/mock.ex).

## Releases

Releases to hex are automatically handled in Travis CI, when a tag is pushed on Github (and a new version has been set in `mix.exs`).
