# Repository graphics QA — 2026-10-30

Result: **PASS**, independently checked by the user-requested QA agent.

- Repository: https://github.com/404kidwiz/devpurge
- Artwork publication commit: `56d6237024dc762bdcb2e8c811195870fdcf9a48`.
- GitHub blob hashes and sizes match local JPEG, PNG master, and generation prompt.
- Public README renders the JPEG beneath the heading, with descriptive alt text.
  Natural size: 1774×887; observed display size: 838×419, preserving the full 2:1 composition.
- Visual inspection passed: correct lettering, legible hierarchy, no clipped text or distortion.

## Social preview

Configured through GitHub repository settings after the owner completed browser authentication.
Verified again after reloading settings. Independent GraphQL verification reports
`usesCustomOpenGraphImage: true` and this `openGraphImageUrl`:

https://repository-images.githubusercontent.com/1205315610/e442248b-2e44-4314-b9e4-9d9c1078dbe8

The served image returns HTTP 200, `image/jpeg`, 839,980 bytes. Its SHA-256 equals
the local JPEG, so GitHub serves the approved artwork without modification:

```text
890e616429fef7b48f78be40e370027f88d465e0a0dba09a7c7e36eb9d117eb7
```

The QA agent viewed the downloaded social image and confirmed the complete cover,
accurate lettering, and no cropped text. External social-network cache refreshes
were not tested. No application code changed; verification covered the published
graphics and repository configuration.
