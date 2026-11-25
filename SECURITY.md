# Security

omarchy-greeter runs at the login screen and the lock screen, handles every account's password, and has parts that run as root. Security reports are very welcome.

## Reporting a vulnerability

Please **do not open a public issue**. Report it privately on GitHub instead: [Security > Report a vulnerability](https://github.com/BrandonDedolph/omarchy-greeter/security/advisories/new). Include what you found, how to reproduce it, and which version (`omarchy-greeter --version`).

You will get an answer within a week. Once a fix is released, the advisory is published with credit to you, unless you prefer otherwise.

## Supported versions

Only the latest release gets fixes. `omarchy update` installs it (see [Updates](README.md#updates)).

## What is in scope

Anything that lets someone get past the login or lock screen, read or change another account's files, gain root, or make the login screen read or run something it should not. The design and its limits are described in the README: [One password at boot](README.md#one-password-at-boot) and [How it works](README.md#how-it-works).

## Release signing

Releases are signed with an SSH key (`ssh-keygen -Y sign`, namespace `omarchy-greeter-release`):

```
SHA256:FUHW/eAyg1oZyYLBpEp072NR5u15Z3heo2QpCmxi2fY
```

The public key is in [`keys/allowed_signers`](keys/allowed_signers) and is installed with the package, which uses it to check every update.
