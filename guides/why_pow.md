# Why Pow

Why should you use Pow instead of any other user management system? Let's take a look at what Pow does differently.

## Functional configuration

No global configuration!

Unlike most alternative user management libraries, Pow is built to be a functional component in your app. You can have numerous separate Pow setups in the same app, e.g., a super admin backend and a regular user login.

Configuration can be passed to nearly all functions in runtime or compile time.

## Modular

Pow has an explicit API for its Plug, Ecto and Phoenix modules. Any part can be removed entirely, or modified. Each of the main category modules has a clear separation of responsibilities that makes it easy to micro adjust the flow.

## Low dependency requirement

Nearly everything is baked in. You won't get into annoying dependency conflicts!

## Extendable

Pow starts out simple: Session management and user registration.

But with Pow you've access to multiple extensions that covers most needs for user management: E-mail confirmation, reset password and long-term session (remember me). There's also a multi-provider library that can be used, e.g. with Twitter and Github.

## Developer friendly

With a clear API in mind, all instructions are written so it's easy to understand the basics of Pow. As you get your first app with Pow up and running, you'll understand the underlying mechanisms. Pow has extensive documentation in all its modules that will clearly show you how Pow works.

Explicit rather than implicit.

## Secure

The basis for security in Pow is industry practices and recommendations from, among others, NIST and OWASP. You can read more in the [README.md](../README.md#pow-security-practices) for specifics.

## Production ready

There are several production apps successfully running Pow. From migration from Coherence to highly customized Pow setups.