<#
.SYNOPSIS
    Export users with assigned SKU IDs and friendly part numbers where Graph provides them.

.DESCRIPTION
    Read-only. Handy for “who is burning M365 E5” without clicking twenty blades.

.NOTES
    SubscribedSku lookup can be empty if Organization.Read.All is missing — script degrades gracefully.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $ExportPath,

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

$skuMap = @{}
try {
    $org = Invoke-MgGraphRequest -Method GET -Uri '/v1.0/subscribedSkus' -ErrorAction Stop
    foreach ($s in $org.value) {
        $skuMap[$s.skuId] = $s.skuPartNumber
    }
    Write-LogLine "Loaded $($skuMap.Count) subscribed SKU mappings."
}
catch {
    Write-LogLine "Could not read subscribedSkus — continuing with raw SKU IDs only. ($($_.Exception.Message))"
}

$select = 'id,userPrincipalName,displayName,accountEnabled,assignedLicenses'
$rows = New-Object System.Collections.Generic.List[object]
$uri = "/v1.0/users?`$select=$select&`$top=999"

while ($uri) {
    $page = Invoke-MgGraphRequest -Method GET -Uri $uri -ErrorAction Stop
    foreach ($u in $page.value) {
        if (-not $u.assignedLicenses -or $u.assignedLicenses.Count -eq 0) {
            continue
        }
        foreach ($lic in $u.assignedLicenses) {
            $sku = $lic.skuId
            $part = $skuMap[$sku]
            $rows.Add([pscustomobject]@{
                    UserPrincipalName = $u.userPrincipalName
                    DisplayName       = $u.displayName
                    AccountEnabled    = $u.accountEnabled
                    SkuId             = $sku
                    SkuPartNumber     = $part
                }) | Out-Null
        }
    }
    $uri = $page.'@odata.nextLink'
}

$dir = Split-Path -Parent $ExportPath
if ($dir -and -not (Test-Path $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

$rows | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding UTF8
Write-LogLine "Wrote $($rows.Count) licence rows to $ExportPath"
