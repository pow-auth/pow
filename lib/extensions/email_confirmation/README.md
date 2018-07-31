# PowEmailConfirmation

This extension will send an e-mail confirmation link when the user registers, and when the user changes their e-mail. It requires that the user schema has an `:email` field.

Users won't be signed in when they register, and can't sign in until the e-mail has been confirmed. The confirmation e-mail will be send everytime the sign in fails. When users are already regstered, the e-mail won't be changed for a user until the user has clicked the e-mail confirmation link.

## Installation

Follow the instructions for extensions in [README.md](../../../README.md), and set `PowEmailConfirmation` in the `:extensions` list.