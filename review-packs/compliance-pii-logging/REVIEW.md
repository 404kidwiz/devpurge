# Review instructions: compliance, PII and logging

## What Important means here

Mark a finding Important when a change can expose personal data: PII written to logs,
analytics or error messages, data sent to a new third party, or retention and deletion
broken. Wording of log messages is Nit at most.

## Always check

- Log lines, error messages and exception reports do not include email addresses, phone numbers, full names, street addresses, government ids, payment card data, passwords, tokens or full request/response bodies.
- New analytics or tracking events do not send PII unless the PR names the consent check that gates it.
- Data sent to a new third-party service (SDK, webhook, API) is listed in the PR description.
- Payment card numbers are never stored or logged; only the processor token and last four digits.
- New tables or fields holding personal data are covered by the account deletion/export path.
- Personal data at rest in new storage is encrypted, or the PR says which existing control covers it.
- Debug logging that prints objects (`console.log(user)`, `print(request)`, `logger.debug(%r)`) is removed or redacted.
- New retention-sensitive data (logs, uploads, backups) has a stated retention period.
- Access to records containing personal data is authorization-checked and audit-logged where the app already has audit logs.

## Do not report

- Synthetic test data that is clearly fake.
- Internal ids that are not linkable to a person outside the system.

## Evidence required

Each finding cites the `file:line` and names the field that carries personal data. Do not
assume a variable holds PII from its name alone; show where it is populated.
