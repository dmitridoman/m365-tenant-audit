<#
.SYNOPSIS
    List users whose last interactive sign-in is older than a threshold (or unknown).

.DESCRIPTION
    Read-only export. Uses signInActivity from Graph user objects when available.

.NOTES
    Requires AuditLog.Read.All for meaningful lastSignInDateTime in many tenants.
    Unknown last sign-in does not prove dead account — it can mean missing permissions or AAD P1/P2 nuances.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [int] $InactiveDays = 90,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $ExportPath,

    [Parameter(Mandatory = $false)]
    [switch] $IncludeGuests,

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

if (-not (Get-Module Microsoft.Graph.Users -ErrorAction SilentlyContinue)) {
    Import-Module Microsoft.Graph.Users -ErrorAction Stop
}

$cutoff = (Get-Date).AddDays(-1 * $InactiveDays).ToUniversalTime()
Write-LogLine "Cutoff (UTC): $cutoff ; inactive days threshold: $InactiveDays"

$select = 'id,userPrincipalName,displayName,accountEnabled,userType,signInActivity,assignedLicenses'
$results = New-Object System.Collections.Generic.List[object]

# Paging — keeps memory steadier than -All on huge tenants (still slow, but honest).
$uri = "/v1.0/users?`$select=$select&`$top=999"

if (-not $IncludeGuests) {
    $encodedFilter = [uri]::EscapeDataString("userType ne 'Guest'")
    $uri += "&`$filter=$encodedFilter"
}

while ($uri) {
    $page = Invoke-MgGraphRequest -Method GET -Uri $uri -ErrorAction Stop
    foreach ($u in $page.value) {
        $last = $null
        if ($u.signInActivity -and $u.signInActivity.lastSignInDateTime) {
            $last = [datetimeoffset]::Parse($u.signInActivity.lastSignInDateTime).UtcDateTime
        }

        $stale = $false
        if (-not $last) {
            $stale = $true # suspicious / unknown — flag for human review
        }
        elseif ($last -lt $cutoff) {
            $stale = $true
        }

        if ($stale) {
            $results.Add([pscustomobject]@{
                    UserPrincipalName = $u.userPrincipalName
                    DisplayName       = $u.displayName
                    AccountEnabled    = $u.accountEnabled
                    UserType          = $u.userType
                    LastSignInUtc     = $last
                    LicenceSkuIds     = ($u.assignedLicenses | ForEach-Object { $_.skuId }) -join ';'
                }) | Out-Null
        }
    }
    $uri = $page.'@odata.nextLink'
}

$dir = Split-Path -Parent $ExportPath
if ($dir -and -not (Test-Path $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

$results | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding UTF8
Write-LogLine "Wrote $($results.Count) rows to $ExportPath"
