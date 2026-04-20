# m365-tenant-audit

Read-only PowerShell for **quick tenant hygiene**: stale-ish accounts, licence assignments, and directory role membership visibility.

Built for quarterly tidy-ups and “why are we paying for this” conversations — not for pretending you have a full GRC platform.

## Prerequisites

- `Microsoft.Graph` modules (`Users`, `Identity.DirectoryManagement`, `Identity.Governance` optional).
- Permissions: `User.Read.All`, `Directory.Read.All`, `Organization.Read.All` as a baseline. Some sign-in fields need **AuditLog.Read.All** — without it, last sign-in may be empty and the script will say so.

## Privileged Identity Management (PIM)

Graph shows **active** directory role assignments reasonably well. **Eligible** PIM assignments are a different API surface (`/roleManagement/directory/roleEligibilitySchedules`) and tenant policies vary. If you live in PIM, expect this repo to be “good enough for a sweep”, not a complete SoD report.

## How to run

```powershell
Connect-MgGraph -Scopes User.Read.All,Directory.Read.All,AuditLog.Read.All,Organization.Read.All

.\scripts\Get-StaleAccounts.ps1 -InactiveDays 90 -ExportPath .\out\stale.csv
.\scripts\Get-LicenceAssignmentReport.ps1 -ExportPath .\out\licences.csv
.\scripts\Get-PrivilegedRoleMembers.ps1 -ExportPath .\out\roles.csv
```

Outputs are CSV. Tune filters before you email them to leadership — raw dumps embarrass people.

## Sample data

`output/sample-report.csv` is **fake** placeholder data for structure only.

## Limits

- Sign-in logs can lag; `lastSignInDateTime` is not perfect for every workload.
- Guest users and cloud-only vs synced users need different interpretation — the scripts do not try to be clever about HR truth.
