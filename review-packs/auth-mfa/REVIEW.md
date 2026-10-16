# Review instructions: authentication and MFA

## What Important means here

Mark a finding Important when a change lets someone sign in, stay signed in, or act as
another user without the checks below: a missing or bypassable MFA step, a session or token
that is not invalidated, a broken authorization check, or a secret in code. Naming and style
in auth code are Nit at most.

## Always check

- Every new or changed login, password reset, email change and account recovery path requires the second factor when the user has MFA enabled; recovery must not skip MFA silently.
- Admin and staff-only routes require MFA, not only a role check.
- New routes and handlers check authorization (who may act on this record), not just authentication (who is signed in); flag any query by record id that is not scoped to the caller.
- Passwords are hashed with bcrypt, scrypt or Argon2; flag MD5, SHA-1, plain SHA-256 or reversible encryption for passwords.
- Session tokens and refresh tokens are invalidated on logout, password change and MFA reset.
- One-time codes and reset tokens expire (15 minutes or less for codes) and can be used once.
- Login, MFA verify and reset endpoints are rate limited or locked out after repeated failures.
- Cookies that carry a session set HttpOnly, Secure and SameSite.
- No API keys, client secrets, private keys or tokens appear in source, tests, fixtures or config committed to the repo.
- JWT verification pins the algorithm and checks signature, expiry and audience; flag `alg: none` or decode-without-verify.

## Do not report

- Lint, formatting and type errors that CI already enforces.
- Test fixtures that use obviously fake credentials such as `test-password` or `example.com` users.

## Evidence required

Each finding cites the `file:line` where the check is missing or bypassed and names the route
or function affected. Do not infer missing MFA from a function name alone; show the call path.
