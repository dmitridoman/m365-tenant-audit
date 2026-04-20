<#
.SYNOPSIS
    Export members of Entra directory roles (Global Administrator, etc.).

.DESCRIPTION
    Read-only. Covers unified role assignments in many tenants. Eligible PIM roles are not included — see README.

.NOTES
    If your tenant names roles differently or uses custom roles, you still get IDs — filter in Excel like a normal person.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $ExportPath,

    [Parameter(Mandatory = $false)]
    [string[]] $RoleTemplateIds,

    [Parameter(Mandatory = $false)]
    [string] $LogPath
)

function Write-LogLine {
    param([string] $Message)
    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[$ts] $Message"
    Write-Host $line
    if ($LogPath) {
        Add-Content -Path $LogPath -Value $line
    }
}

if ($LogPath) {
    $logDir = Split-Path -Parent $LogPath
    if ($logDir -and -not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
}

if (-not (Get-Module Microsoft.Graph.Identity.DirectoryManagement -ErrorAction SilentlyContinue)) {
    Import-Module Microsoft.Graph.Identity.DirectoryManagement -ErrorAction Stop
}

# Well-known template ids are stable enough to use as filters when you only care about the usual suspects.
if (-not $RoleTemplateIds -or $RoleTemplateIds.Count -eq 0) {
    $RoleTemplateIds = @(
        '62e90394-69f5-4237-9190-012177145e10', # Global Administrator
        '194ae4cb-b126-40b2-bd5b-6091b380977d', # Security Administrator
        '29232cdf-9323-42fd-ade2-1d097af3e4de', # Exchange Administrator
        '729827e3-9c14-49f7-bb1b-9608f156bbb8', # Helpdesk Administrator
    )
    Write-LogLine "Using default role template id filter set ($($RoleTemplateIds.Count) roles)."
}

$roleRows = New-Object System.Collections.Generic.List[object]

foreach ($tpl in $RoleTemplateIds) {
    $role = Get-MgDirectoryRole -Filter "roleTemplateId eq '$tpl'" -ConsistencyLevel eventual -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $role) {
        Write-LogLine "Role for template $tpl not activated in tenant — skipping."
        continue
    }

    $members = Get-MgDirectoryRoleMember -DirectoryRoleId $role.Id -All -ErrorAction Stop
    foreach ($m in $members) {
        $type = $m.AdditionalProperties['@odata.type']
        $upn = $m.AdditionalProperties['userPrincipalName']
        $name = $m.AdditionalProperties['displayName']
        $roleRows.Add([pscustomobject]@{
                RoleDisplayName = $role.DisplayName
                RoleTemplateId  = $tpl
                MemberType      = $type
                MemberId        = $m.Id
                UserPrincipalName = $upn
                DisplayName     = $name
            }) | Out-Null
    }
}

$dir = Split-Path -Parent $ExportPath
if ($dir -and -not (Test-Path $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

$roleRows | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding UTF8
Write-LogLine "Wrote $($roleRows.Count) role member rows to $ExportPath"
Write-LogLine "Reminder: PIM eligible assignments are not in this export."
