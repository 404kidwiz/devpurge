# Website hosting

The production website is https://devpurge.com/ on Vercel. Hostinger remains the
domain registrar and DNS provider. GitHub stores source and the public Mac download.

## Vercel project

- Team: `404kidwizs-projects`
- Project: `devpurge` (`prj_hmWXoimkZ8a1pB199CBVy5K3dBar`)
- Source: `404kidwiz/devpurge`, production branch `main`
- Root directory: `site`
- Framework: Other / none
- Build command and install command: empty (static files, no build step)
- Output directory: `.`

Deploy only `site/`, not the repository root. `site/CNAME` and the disabled
GitHub Pages workflow are legacy configuration, not the production hosting path.
The Pages workflow was disabled and its custom-domain binding removed on
2026-10-30; do not re-enable it during normal website updates.

## Domain configuration

Hostinger DNS as configured on 2026-10-30 (TTL 300):

| Type | Name | Value |
| --- | --- | --- |
| A | @ | 216.150.1.1 |
| A | @ | 216.150.16.1 |
| CNAME | www | f9852d1c7daccf67.vercel-dns-016.com |

These values came from this Vercel project's domain configuration. Refresh that
configuration before future DNS edits, because provider recommendations may change.
Both domains are assigned to the project. `www.devpurge.com` redirects to the apex
with HTTP 308. The certificate covers both names with automatic renewal enabled.

## Verification after an update

1. Confirm the production deployment is READY and references the intended commit.
2. Open https://devpurge.com/ and https://www.devpurge.com/; confirm the canonical
   apex URL, valid HTTPS, and Vercel response headers.
3. Check the stylesheet, JavaScript, fonts, images and Mac download link.
4. Keep both license buttons disabled until Lemon Squeezy explicitly approves the
   store and live checkout plus app license activation have passed verification.

Lemon Squeezy approval and Mac signing/notarization are separate launch checks;
changing website hosts does not complete them.
