# Audit use cases

Things you actually do with these scripts in a normal admin job.

## Quarterly licence sweep

Finance forwards a spreadsheet; you verify **who has a SKU** and whether they signed in this decade. Export licence assignments, join mentally with HR data outside this repo, then raise removals or downgrades.

**Gotcha:** group-based licensing means the user might “have” apps without a direct SKU row looking obvious — check group memberships before you pick fights.

## Stale account hunt

Pick a threshold (`InactiveDays`) that matches risk, not vanity. Ninety days is common; regulated shops sometimes go shorter; schools can be messy during holidays.

Use the export as a **candidate list**. Some accounts are intentionally quiet (break-glass, service principals are not users anyway, shared scenarios exist).

## Admin exposure review

Dump directory role members, paste into your change ticket, fix what drifted. This does not replace PIM workflows, but it catches “Bob still Global Admin because nobody cleaned the ticket”.

**Gotcha:** eligible PIM assignments will not show up in the basic role assignment query — do not declare victory without checking PIM if you use it.

## Pre-acquisition / tenant tidy (boring but real)

Before you merge tenants or decommission apps, you want unused humans and licence waste mapped. These scripts are cheap compared to vendor tools; they are also narrower.

## What this is not

- Not DLP, not insider risk, not full access reviews with attestation.
- Not a substitute for Entra ID Access Reviews — those exist for a reason.
