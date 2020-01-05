# Pow security practices

Some of the below is based on [OWASP](https://www.owasp.org/) or [NIST SP800-63b](https://pages.nist.gov/800-63-3/sp800-63b.html) recommendations.

## User ID

* The `user_id_field` value is always treated as case insensitive
* If the `user_id_field` is `:email`, it'll be validated based on RFC 5322 (sections 3.2.3 and 3.4.1) and RFC 5321 with unicode characters permitted in local and domain part

## Password

* The `:password` has a minimum length of 8 characters
* The `:password` has a maximum length of 4096 bytes [to prevent DOS attacks against Pbkdf2](https://github.com/riverrun/pbkdf2_elixir/blob/master/lib/pbkdf2.ex#L21)
* The `:password_hash` is generated with `PBKDF2-SHA512` with 100,000 iterations

## Session management

* The session value contains a UUID token that is used to pull credentials through a GenServer
* The credentials are stored in a key-value cache with TTL of 30 minutes
* The credentials and session are renewed after 15 minutes if any activity is detected
* The credentials and session are renewed when user updates

## Timing attacks

* If a user couldn't be found or the `:password_hash` is `nil` a blank password is used
* A UUID is always generated during reset password flow

## Information leak

* If `PowEmailConfirmation` extension is used or registration has been disabled, the reset password flow will always return success message
* If `PowEmailConfirmation` extension is used and a user can't be found, the registration and sign in page will redirect the user with a message to confirm their e-mail before they can sign in

## Browser cache

* The sign in, registration and invitation acceptance page won't be cached by the browser
