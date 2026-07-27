# CURRENT SITE LOCK POLICY

Effective date: 2026-07-27
Status: ENFORCED

## Purpose
This repository is locked to a single live site strategy.
All future work must be executed on the current site only.

## Mandatory Rules
1. Do all new jobs and updates in the current site codebase only.
2. Do not create a new site, duplicate site, parallel site, or alternate production site.
3. Do not prepare new-site deployment tracks, domains, or separate branding branches for a new site.
4. Keep using the current deployment pipeline for the same site baseline.
5. If any task implies a separate/new site, stop and request explicit owner override.

## Allowed Work
- In-place feature updates
- Bug fixes and reliability work
- Performance, SEO, and content updates
- Branding updates on the same current site
- Backup, monitoring, and release maintenance for the same site

## Change Control
This lock remains active unless the owner publishes an explicit written override in project logs.
