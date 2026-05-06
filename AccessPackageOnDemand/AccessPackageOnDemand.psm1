<#
.SYNOPSIS
    AccessPackageOnDemand — interactive on-demand assignment for Entra ID
    Access Packages via Microsoft Graph.

.DESCRIPTION
    Public commands:
      Start-AccessPackageOnDemand   — interactive assignment flow
      Set-AccessPackageConfig       — interactive setup menu
      Get-AccessPackageConfig       — returns the configured packages
      Clear-AccessPackageConfig     — wipes the config file
#>

# ─── Script-scope state ──────────────────────────────────────────────────────
$script:ESC        = [char]0x1B
$script:ConfigPath = Join-Path $env:LOCALAPPDATA 'AccessPackageOnDemand\config.json'

# ═══════════════════════════════════════════════════════════════════════════
#  Config storage  (PUBLIC)
# ═══════════════════════════════════════════════════════════════════════════

function Get-AccessPackageConfig {
    [CmdletBinding()]
    param()
    if (-not (Test-Path $script:ConfigPath)) { return @() }
    try {
        $cfg = Get-Content $script:ConfigPath -Raw | ConvertFrom-Json
        # Filter out null / malformed entries so a corrupt save can't show as a blank row
        return @($cfg.Packages | Where-Object { $_ -and $_.DisplayName -and $_.Id })
    } catch {
        return @()
    }
}

function Save-AccessPackageConfig {
    [CmdletBinding()]
    param([array]$Packages)
    $dir = Split-Path $script:ConfigPath -Parent
    if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
    @{ Packages = $Packages } | ConvertTo-Json -Depth 10 | Set-Content $script:ConfigPath -Force
}

function Clear-AccessPackageConfig {
    [CmdletBinding()]
    param()
    if (Test-Path $script:ConfigPath) {
        Remove-Item $script:ConfigPath -Force
        Write-Host "Configuration cleared." -ForegroundColor Green
    } else {
        Write-Host "No configuration file found." -ForegroundColor Yellow
    }
}

function Set-AccessPackageConfig {
    [CmdletBinding()]
    param()
    $ESC = $script:ESC
    while ($true) {
        $existing = @(Get-AccessPackageConfig)
        Clear-Host
        Write-Host ""
        Write-Host "  ${ESC}[1;97mConfigure Managed Access Packages${ESC}[0m"
        Write-Host "  ${ESC}[90m─────────────────────────────────${ESC}[0m"
        Write-Host ""
        if ($existing.Count -gt 0) {
            Write-Host "  ${ESC}[1;97mCurrently configured ($($existing.Count)):${ESC}[0m"
            foreach ($p in $existing) {
                Write-Host "    ${ESC}[90m·${ESC}[0m $($p.DisplayName) ${ESC}[90m($($p.Id))${ESC}[0m"
            }
            Write-Host ""
        } else {
            Write-Host "  ${ESC}[33mNo packages configured yet.${ESC}[0m"
            Write-Host ""
        }
        Write-Host "  ${ESC}[1;97mOptions${ESC}[0m"
        Write-Host "    ${ESC}[36m1${ESC}[0m  Add a package"
        Write-Host "    ${ESC}[36m2${ESC}[0m  Remove a package"
        Write-Host "    ${ESC}[36m3${ESC}[0m  Replace all (start fresh)"
        Write-Host "    ${ESC}[36m4${ESC}[0m  Done"
        Write-Host ""
        $choice = (Read-Host '  Select option (1-4)').Trim()
        if ($choice -notmatch '^[1-4]$') { continue }
        if ($choice -eq '4') { return }

        switch ($choice) {
            '1' {
                $id = (Read-Host '  Access Package Object ID (GUID)').Trim()
                if ([string]::IsNullOrWhiteSpace($id)) { continue }
                try { $null = [System.Guid]::Parse($id) }
                catch { Write-Host "  ${ESC}[31mInvalid GUID format.${ESC}[0m"; Start-Sleep -Milliseconds 800; continue }
                if ($existing | Where-Object { $_.Id -eq $id }) {
                    Write-Host "  ${ESC}[33mAlready configured.${ESC}[0m"; Start-Sleep -Milliseconds 800; continue
                }
                $name = (Read-Host '  Friendly name (DisplayName)').Trim()
                if ([string]::IsNullOrWhiteSpace($name)) { Write-Host "  ${ESC}[33mName required.${ESC}[0m"; Start-Sleep -Milliseconds 800; continue }
                $all = @($existing) + @{ DisplayName = $name; Id = $id }
                Save-AccessPackageConfig -Packages $all
                Write-Host "  ${ESC}[32mAdded.${ESC}[0m"; Start-Sleep -Milliseconds 600
            }
            '2' {
                if ($existing.Count -eq 0) { Write-Host "  Nothing to remove."; Start-Sleep -Milliseconds 600; continue }
                Write-Host ""
                for ($i = 0; $i -lt $existing.Count; $i++) {
                    Write-Host "    ${ESC}[36m$($i+1)${ESC}[0m $($existing[$i].DisplayName)"
                }
                $sel = (Read-Host '  Number to remove').Trim()
                if ($sel -notmatch '^\d+$') { continue }
                $idx = [int]$sel - 1
                if ($idx -lt 0 -or $idx -ge $existing.Count) { continue }
                $removed = $existing[$idx]
                $remaining = @($existing | Where-Object { $_.Id -ne $removed.Id })
                Save-AccessPackageConfig -Packages $remaining
                Write-Host "  ${ESC}[32mRemoved: $($removed.DisplayName)${ESC}[0m"; Start-Sleep -Milliseconds 600
            }
            '3' {
                Write-Host "  Enter packages one at a time. Empty ID finishes."
                $new = @(); $n = 1
                while ($true) {
                    $id = (Read-Host "  Package $n - Object ID (Enter to finish)").Trim()
                    if ([string]::IsNullOrWhiteSpace($id)) { break }
                    try { $null = [System.Guid]::Parse($id) }
                    catch { Write-Host "  ${ESC}[31mInvalid GUID — skipping.${ESC}[0m"; continue }
                    $name = (Read-Host '  Friendly name').Trim()
                    if ([string]::IsNullOrWhiteSpace($name)) { Write-Host "  ${ESC}[33mName empty — skipping.${ESC}[0m"; continue }
                    $new += @{ DisplayName = $name; Id = $id }
                    $n++
                }
                if ($new.Count -gt 0) {
                    Save-AccessPackageConfig -Packages $new
                    Write-Host "  ${ESC}[32mSaved $($new.Count) package(s).${ESC}[0m"
                }
                Start-Sleep -Milliseconds 600
            }
        }
    }
}

# ═══════════════════════════════════════════════════════════════════════════
#  TUI helpers (PRIVATE)
# ═══════════════════════════════════════════════════════════════════════════

function Write-Banner {
    param([string]$Title)
    $ESC = $script:ESC
    Write-Host ""
    Write-Host "  ${ESC}[1;97m$Title${ESC}[0m"
    Write-Host "  ${ESC}[90m$('─' * $Title.Length)${ESC}[0m"
    Write-Host ""
}

function Write-Status {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('Info','Success','Warning','Error')][string]$Level = 'Info'
    )
    $ESC = $script:ESC
    $color = switch ($Level) {
        'Info'    { '36' }
        'Success' { '32' }
        'Warning' { '33' }
        'Error'   { '31' }
    }
    $glyph = switch ($Level) {
        'Info'    { 'i' }
        'Success' { '+' }
        'Warning' { '!' }
        'Error'   { 'x' }
    }
    Write-Host "${ESC}[${color}m[$glyph]${ESC}[0m $Message"
}

function Start-CoolingOffCountdown {
    param([int]$Seconds = 300)
    $ESC = $script:ESC
    Write-Host ""
    Write-Host "  ${ESC}[33m[~]${ESC}[0m  Waiting for assignments to process"
    Write-Host ""
    for ($remaining = $Seconds; $remaining -ge 0; $remaining--) {
        $mins = [Math]::Floor($remaining / 60)
        $secs = $remaining % 60
        Write-Host -NoNewline "`r  ${ESC}[36m$([string]::Format('{0}:{1:D2}', $mins, $secs))${ESC}[0m remaining  (Press ${ESC}[97mCtrl+C${ESC}[0m to skip)  "
        if ($remaining -gt 0) { Start-Sleep -Seconds 1 }
    }
    Write-Host "`r  ${ESC}[32m[+]${ESC}[0m Cooling-off complete.                              "
    Write-Host ""
}

function Show-Confirmation {
    param(
        [Parameter(Mandatory)][string]$Prompt,
        [bool]$Default = $false
    )
    $hint = if ($Default) { '[Y/n]' } else { '[y/N]' }
    Write-Host -NoNewline "  $Prompt $hint "
    $resp = Read-Host
    if ([string]::IsNullOrWhiteSpace($resp)) { return $Default }
    return ($resp.Trim() -match '^[yY]')
}

function Select-FromList {
    param(
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][array]$Items,
        [Parameter(Mandatory)][scriptblock]$DisplayFormat
    )
    $ESC = $script:ESC
    while ($true) {
        Clear-Host
        Write-Banner $Title
        for ($i = 0; $i -lt $Items.Count; $i++) {
            $line = & $DisplayFormat $Items[$i]
            Write-Host ("  ${ESC}[36m{0,3}.${ESC}[0m {1}" -f ($i + 1), $line)
        }
        Write-Host ""
        Write-Host -NoNewline "  Enter selection number ${ESC}[90m(Q to quit)${ESC}[0m: "
        $sel = Read-Host
        if ($sel -match '^[qQ]$') { return $null }
        if ($sel -match '^\d+$') {
            $idx = [int]$sel - 1
            if ($idx -ge 0 -and $idx -lt $Items.Count) {
                return $Items[$idx]
            }
        }
        Write-Status "Invalid selection." -Level Warning
        Start-Sleep -Milliseconds 800
    }
}

# ═══════════════════════════════════════════════════════════════════════════
#  Graph connection (PRIVATE)
# ═══════════════════════════════════════════════════════════════════════════

function Assert-GraphModules {
    $required = @(
        'Microsoft.Graph.Authentication',
        'Microsoft.Graph.Identity.Governance',
        'Microsoft.Graph.Users'
    )
    $missing = @()
    foreach ($m in $required) {
        if (-not (Get-Module -ListAvailable -Name $m)) { $missing += $m }
    }
    if ($missing.Count -gt 0) {
        Write-Status "Missing required modules: $($missing -join ', ')" -Level Error
        Write-Host "  Install with:"
        Write-Host "    Install-Module $($missing -join ', ') -Scope CurrentUser -Force"
        return $false
    }
    foreach ($m in $required) { Import-Module $m -ErrorAction SilentlyContinue }
    return $true
}

function Connect-GraphSession {
    $scopes = @(
        'EntitlementManagement.ReadWrite.All',
        'User.Read.All'
    )
    try {
        $ctx = Get-MgContext -ErrorAction SilentlyContinue
        $hasAll = $ctx -and -not ($scopes | Where-Object { $ctx.Scopes -notcontains $_ })
        if ($hasAll) { return $true }
        Connect-MgGraph -Scopes $scopes -NoWelcome -ErrorAction Stop | Out-Null
        return $true
    } catch {
        Write-Status "Authentication failed: $($_.Exception.Message)" -Level Error
        return $false
    }
}

# ═══════════════════════════════════════════════════════════════════════════
#  Access Packages (PRIVATE)
# ═══════════════════════════════════════════════════════════════════════════

function Select-AccessPackage {
    param([Parameter(Mandatory)][array]$Packages)
    return Select-FromList -Title "Select Access Package" -Items $Packages -DisplayFormat {
        param($p) "$($p.DisplayName)"
    }
}

function Select-AssignmentPolicy {
    param([Parameter(Mandatory)]$AccessPackage)
    Write-Status "Loading assignment policies ..." -Level Info
    try {
        $pkgId = $AccessPackage.Id
        $uri  = "/v1.0/identityGovernance/entitlementManagement/assignmentPolicies?`$filter=accessPackage/id eq '$pkgId'"
        $resp = Invoke-MgGraphRequest -Method GET -Uri $uri -ErrorAction Stop
        $policies = @($resp.value) | Sort-Object displayName
        $policies = $policies | ForEach-Object {
            [pscustomobject]@{
                Id          = $_.id
                DisplayName = $_.displayName
                Description = $_.description
                Raw         = $_
            }
        }
    } catch {
        Write-Status "Failed to load policies: $($_.Exception.Message)" -Level Error
        return $null
    }
    $policies = @($policies)
    if ($policies.Count -eq 0) {
        Write-Status "No assignment policies found for this access package." -Level Warning
        return $null
    }
    if ($policies.Count -eq 1) {
        return $policies[0]
    }
    return Select-FromList -Title "Select Assignment Policy" -Items $policies -DisplayFormat {
        param($p) "$($p.DisplayName)"
    }
}

function Get-ExistingAssignments {
    param(
        [Parameter(Mandatory)][string]$AccessPackageId,
        [Parameter(Mandatory)][string]$AssignmentPolicyId
    )
    Write-Status "Loading existing assignments ..." -Level Info
    $map = @{}
    try {
        $filter = "accessPackage/id eq '$AccessPackageId' and assignmentPolicy/id eq '$AssignmentPolicyId'"
        $uri = "/v1.0/identityGovernance/entitlementManagement/assignments?`$filter=$filter&`$expand=target"
        $resp = Invoke-MgGraphRequest -Method GET -Uri $uri -ErrorAction Stop
        foreach ($a in @($resp.value)) {
            $s = ($a.state ?? '').ToString().ToLowerInvariant()
            if ($s -in @('delivered','delivering','partiallydelivered')) {
                if ($a.target -and $a.target.id) { $map[$a.target.id] = $a }
            }
        }
    } catch {
        Write-Status "Could not load existing assignments: $($_.Exception.Message)" -Level Warning
    }
    return $map
}

function Show-PackageAssignments {
    param(
        [Parameter(Mandatory)][string]$AccessPackageId,
        [Parameter(Mandatory)][string]$AssignmentPolicyId,
        [string]$PackageName,
        [string]$PolicyName
    )
    [void]$PolicyName
    $ESC = $script:ESC

    while ($true) {
        Clear-Host
        Write-Banner "Current Assignments — $PackageName"
        Write-Host "  ${ESC}[90mFetching live state ...${ESC}[0m"

        $filter = "accessPackage/id eq '$AccessPackageId' and assignmentPolicy/id eq '$AssignmentPolicyId'"

        $assignments = @()
        $allAssign   = @()
        try {
            $uri = "/v1.0/identityGovernance/entitlementManagement/assignments?`$filter=$filter&`$expand=target"
            $r = Invoke-MgGraphRequest -Method GET -Uri $uri -ErrorAction Stop
            $allAssign   = @($r.value)
            $activeRaw = @(
                $allAssign | Where-Object {
                    $s = ($_.state ?? '').ToString().ToLowerInvariant()
                    $s -in @('delivered','delivering','partiallydelivered')
                }
            )
            # Dedupe by target.id — multiple historical "delivered" records can stack
            # for the same user. Keep the most recent (or first, if no timestamps).
            $assignments = @(
                $activeRaw |
                    Group-Object -Property { $_.target.id } |
                    ForEach-Object {
                        $_.Group |
                            Sort-Object @{Expression={$_.createdDateTime}; Descending=$true} |
                            Select-Object -First 1
                    } |
                    Sort-Object { $_.target.displayName }
            )
        } catch {
            Write-Status "Failed to load assignments: $($_.Exception.Message)" -Level Error
            return
        }

        $pendingReqs = @()
        try {
            $uri2 = "/v1.0/identityGovernance/entitlementManagement/assignmentRequests?`$filter=$filter&`$expand=target,requestor"
            $r2 = Invoke-MgGraphRequest -Method GET -Uri $uri2 -ErrorAction Stop
            $pendingReqs = @(
                $r2.value | Where-Object {
                    $s = ($_.state ?? '').ToString().ToLowerInvariant()
                    $s -notin @('delivered','failed','denied','canceled','cancelled','partiallydelivered')
                }
            ) | Sort-Object { $_.target.displayName }
        } catch { }

        Clear-Host
        Write-Banner "Current Assignments — $PackageName"

        if ($assignments.Count -eq 0 -and $pendingReqs.Count -eq 0) {
            if ($allAssign.Count -gt 0) {
                Write-Status "No active assignments — $($allAssign.Count) record(s) only in non-active states:" -Level Warning
                $stateGroups = $allAssign | Group-Object { ($_.state ?? '').ToString() } | Sort-Object Name
                foreach ($g in $stateGroups) {
                    Write-Host "    ${ESC}[90m$($g.Count) × $($g.Name)${ESC}[0m"
                }
            } else {
                Write-Status "No assignments or pending requests for this package+policy." -Level Warning
            }
        }

        if ($assignments.Count -gt 0) {
            Write-Host "  ${ESC}[1;97mActive ($($assignments.Count)):${ESC}[0m"
            $i = 1
            foreach ($a in $assignments) {
                $name  = $a.target.displayName
                $email = $a.target.email
                $state = $a.state
                $label = switch ($state) {
                    'delivered'          { 'active' }
                    'delivering'         { 'delivering' }
                    'partiallyDelivered' { 'partial' }
                    default              { $state }
                }
                $color = switch ($state) {
                    'delivered'          { '32' }
                    'delivering'         { '36' }
                    'partiallyDelivered' { '33' }
                    default              { '90' }
                }
                Write-Host ("  ${ESC}[36m{0,3}.${ESC}[0m  {1,-36} ${ESC}[90m{2,-42}${ESC}[0m ${ESC}[${color}m{3}${ESC}[0m" -f $i, $name, $email, $label)
                $i++
            }
            Write-Host ""
        }

        if ($pendingReqs.Count -gt 0) {
            Write-Host "  ${ESC}[1;97mIn-flight requests ($($pendingReqs.Count)):${ESC}[0m"
            $j = 1
            foreach ($q in $pendingReqs) {
                $name  = $q.target.displayName
                $email = $q.target.email
                $state = $q.state
                Write-Host ("    ${ESC}[36m{0,3}.${ESC}[0m {1,-35} ${ESC}[90m{2,-32}${ESC}[0m ${ESC}[33m{3}${ESC}[0m" -f $j, $name, $email, $state)
                $j++
            }
            Write-Host ""
        }

        Write-Host -NoNewline "  ${ESC}[97mR${ESC}[0m=refresh   ${ESC}[97mENTER${ESC}[0m=continue : "
        $resp = Read-Host
        if ($resp.Trim() -notmatch '^[rR]$') { return }
    }
}

# ═══════════════════════════════════════════════════════════════════════════
#  User selection (PRIVATE)
# ═══════════════════════════════════════════════════════════════════════════

function Read-UsersByEmail {
    param([hashtable]$ExistingAssignments = @{})
    $ESC = $script:ESC

    Clear-Host
    Write-Banner "Add User(s) by Email"
    Write-Host "  ${ESC}[90mEnter one or more email addresses (comma, space, or semicolon separated).${ESC}[0m"
    Write-Host ""
    Write-Host -NoNewline "  Email(s) ${ESC}[90m(Q to quit)${ESC}[0m: "
    $entry = Read-Host
    if ([string]::IsNullOrWhiteSpace($entry)) { return @() }
    if ($entry.Trim() -match '^[qQ]$')        { return @() }

    $emails = $entry -split '[,\s;]+' | Where-Object { $_ -ne '' } | Select-Object -Unique

    $resolved = @()
    Write-Host ""
    foreach ($raw in $emails) {
        $email   = $raw.Trim()
        $escaped = $email.Replace("'", "''")
        Write-Host -NoNewline "  $email "
        try {
            $user = Get-MgUser `
                        -Filter "userPrincipalName eq '$escaped' or mail eq '$escaped'" `
                        -Property Id,DisplayName,UserPrincipalName,Mail `
                        -Top 1 -ErrorAction Stop | Select-Object -First 1
        } catch {
            Write-Host "${ESC}[31m→ lookup error: $($_.Exception.Message)${ESC}[0m"
            continue
        }
        if (-not $user) {
            Write-Host "${ESC}[31m→ not found${ESC}[0m"
            continue
        }
        if ($ExistingAssignments.ContainsKey($user.Id)) {
            Write-Host "${ESC}[33m→ already has access${ESC}[0m  ${ESC}[90m($($user.DisplayName))${ESC}[0m"
        } else {
            Write-Host "${ESC}[32m→ ready to assign${ESC}[0m  ${ESC}[90m($($user.DisplayName))${ESC}[0m"
        }
        $resolved += $user
    }

    Write-Host ""
    if ($resolved.Count -eq 0) {
        Write-Status "No users resolved." -Level Warning
        Start-Sleep -Seconds 2
    } else {
        Start-Sleep -Milliseconds 600
    }
    return @($resolved)
}

# ═══════════════════════════════════════════════════════════════════════════
#  Duration helpers (PRIVATE)
# ═══════════════════════════════════════════════════════════════════════════

function Convert-IsoDurationToTimeSpan {
    param([string]$Duration)
    if (-not $Duration) { return $null }
    try { return [System.Xml.XmlConvert]::ToTimeSpan($Duration) } catch { }
    if ($Duration -match '^P(?:(\d+)Y)?(?:(\d+)M)?(?:(\d+)D)?$') {
        $years  = [int]($matches[1])
        $months = [int]($matches[2])
        $days   = [int]($matches[3])
        return [TimeSpan]::FromDays(($years * 365) + ($months * 30) + $days)
    }
    return $null
}

function Format-DurationFriendly {
    param([TimeSpan]$TimeSpan)
    $days = $TimeSpan.TotalDays
    if ($days -ge 365 -and ($days % 365 -eq 0)) {
        $y = [int]($days / 365)
        return "$y Year$(if ($y -ne 1) {'s'})"
    }
    if ($days -ge 1) {
        $d = [int][Math]::Round($days)
        return "$d Day$(if ($d -ne 1) {'s'})"
    }
    $m = [int][Math]::Round($TimeSpan.TotalMinutes)
    return "$m Minute$(if ($m -ne 1) {'s'})"
}

# ═══════════════════════════════════════════════════════════════════════════
#  Main flow  (PUBLIC)
# ═══════════════════════════════════════════════════════════════════════════

function Start-AccessPackageOnDemand {
    [CmdletBinding()]
    param()
    $ESC = $script:ESC

    if (-not (Assert-GraphModules))  { return }
    if (-not (Connect-GraphSession)) { return }

    do {
        Invoke-AssignmentFlowOnce
        Write-Host ""
        Write-Host -NoNewline "  ${ESC}[97mR${ESC}[0m=run again   ${ESC}[97mENTER${ESC}[0m=exit : "
        $next = Read-Host
    } while ($next.Trim() -match '^[rR]$')
}

function Invoke-AssignmentFlowOnce {
    [CmdletBinding()]
    param()
    $ESC = $script:ESC

    Clear-Host
    Write-Banner "Access Package Assignment Manager"

    # Step 2: Select Access Package (from configured list)
    $configured = @(Get-AccessPackageConfig)
    if ($configured.Count -eq 0) {
        Write-Status "No access packages configured." -Level Error
        Write-Host ""
        Write-Host "  Run setup first:"
        Write-Host "    ${ESC}[36mSet-AccessPackageConfig${ESC}[0m"
        Write-Host ""
        return
    }

    $packages = @($configured | ForEach-Object {
        [pscustomobject]@{ DisplayName = $_.DisplayName; Id = $_.Id }
    })

    if ($packages.Count -eq 1) {
        $chosenPackage = $packages[0]
    } else {
        $chosenPackage = Select-AccessPackage -Packages $packages
        if (-not $chosenPackage) {
            Write-Status "Cancelled." -Level Warning
            return
        }
    }

    # Step 3: Select Assignment Policy
    $chosenPolicy = Select-AssignmentPolicy -AccessPackage $chosenPackage
    if (-not $chosenPolicy) {
        Write-Status "Cancelled." -Level Warning
        return
    }

    # Step 4: Load existing assignments
    Write-Host ""
    $existingAssignments = Get-ExistingAssignments `
        -AccessPackageId $chosenPackage.Id `
        -AssignmentPolicyId $chosenPolicy.Id

    # Step 5: Enter user email(s)
    $selectedUsers = @(Read-UsersByEmail -ExistingAssignments $existingAssignments)
    if ($selectedUsers.Count -eq 0) {
        Write-Status "No users selected — exiting." -Level Warning
        return
    }

    $toAssign = @($selectedUsers | Where-Object { -not $existingAssignments.ContainsKey($_.Id) })

    # Step 6: Assignment details
    Clear-Host
    Write-Banner "Assignment Details"

    Write-Host "  ${ESC}[1;97mAccess Package:${ESC}[0m  $($chosenPackage.DisplayName)"
    Write-Host "  ${ESC}[1;97mUsers selected:${ESC}[0m  $($selectedUsers.Count)"
    Write-Host ""

    foreach ($u in $selectedUsers) {
        if ($existingAssignments.ContainsKey($u.Id)) {
            Write-Host "    ${ESC}[1;31m[skip]${ESC}[0m $($u.DisplayName)  ${ESC}[90m<$($u.UserPrincipalName)>${ESC}[0m ${ESC}[31m— already assigned${ESC}[0m"
        } else {
            Write-Host "    ${ESC}[32m[+]${ESC}[0m    $($u.DisplayName)  ${ESC}[90m<$($u.UserPrincipalName)>${ESC}[0m"
        }
    }
    Write-Host ""

    if ($toAssign.Count -eq 0) {
        Write-Status "All selected users are already assigned. Nothing to do." -Level Warning
        return
    }

    $startDate = (Get-Date).ToUniversalTime()

    $policyExp = $null
    if ($chosenPolicy.Raw -and $chosenPolicy.Raw.expiration) {
        $policyExp = $chosenPolicy.Raw.expiration
    }

    $endDate    = $null
    $hasEndDate = $false
    $endSource  = '(noExpiration)'

    if ($policyExp) {
        switch ($policyExp.type) {
            'afterDuration' {
                $ts = Convert-IsoDurationToTimeSpan -Duration $policyExp.duration
                if ($ts) {
                    $endDate    = $startDate.Add($ts)
                    $hasEndDate = $true
                    $endSource  = "policy max ($(Format-DurationFriendly $ts))"
                }
            }
            'afterDateTime' {
                try {
                    $endDate    = ([datetime]$policyExp.endDateTime).ToUniversalTime()
                    $hasEndDate = $true
                    $endSource  = "policy max ($($endDate.ToLocalTime().ToString('yyyy-MM-dd')))"
                } catch { }
            }
            'noExpiration' { }
        }
    }

    # Business justification (required) — canned options + custom
    $cannedJustifications = @(
        'Intune and Autopilot Enrollments',
        'Reprocess and Retry - Intune and Autopilot Enrollment'
    )
    $justification = $null
    while ([string]::IsNullOrWhiteSpace($justification)) {
        Write-Host ""
        Write-Host "  ${ESC}[1;97mBusiness justification${ESC}[0m ${ESC}[91m(required)${ESC}[0m"
        for ($ji = 0; $ji -lt $cannedJustifications.Count; $ji++) {
            Write-Host ("    ${ESC}[36m{0}${ESC}[0m  {1}" -f ($ji + 1), $cannedJustifications[$ji])
        }
        Write-Host "    ${ESC}[36mC${ESC}[0m  Custom (type your own)"
        Write-Host ""
        Write-Host -NoNewline "  Choose: "
        $pick = (Read-Host).Trim()

        if ($pick -match '^\d+$') {
            $idx = [int]$pick - 1
            if ($idx -ge 0 -and $idx -lt $cannedJustifications.Count) {
                $justification = $cannedJustifications[$idx]
            }
        } elseif ($pick -match '^[cC]$') {
            Write-Host -NoNewline "  Custom justification: "
            $justification = Read-Host
        }

        if ([string]::IsNullOrWhiteSpace($justification)) {
            Write-Status "Pick a number or C for custom — justification is required." -Level Warning
        }
    }
    $justification = $justification.Trim()

    # Step 7: Confirm
    Write-Host ""
    Write-Host "  ${ESC}[36m─────────────────────────────────────────────────${ESC}[0m"
    Write-Host "  ${ESC}[1;97mPackage:${ESC}[0m    $($chosenPackage.DisplayName)"
    Write-Host "  ${ESC}[1;97mStarts:${ESC}[0m     $($startDate.ToLocalTime().ToString('yyyy-MM-dd hh:mm tt'))"
    if ($hasEndDate) {
        Write-Host "  ${ESC}[1;97mEnds:${ESC}[0m       $($endDate.ToLocalTime().ToString('yyyy-MM-dd hh:mm tt')) ${ESC}[90m($endSource)${ESC}[0m"
    } else {
        Write-Host "  ${ESC}[1;97mEnds:${ESC}[0m       ${ESC}[90m(no expiration — policy allows it)${ESC}[0m"
    }
    if ($justification) {
        Write-Host "  ${ESC}[1;97mJustification:${ESC}[0m $justification"
    }
    Write-Host "  ${ESC}[1;97mWill assign:${ESC}[0m $($toAssign.Count) user(s):"
    foreach ($u in $toAssign) {
        Write-Host "    ${ESC}[32m+${ESC}[0m $($u.DisplayName)  ${ESC}[90m<$($u.UserPrincipalName)>${ESC}[0m"
    }
    Write-Host "  ${ESC}[36m─────────────────────────────────────────────────${ESC}[0m"

    $promptText = if ($toAssign.Count -eq 1) { 'Assign this user?' } else { "Assign these $($toAssign.Count) users?" }
    if (-not (Show-Confirmation -Prompt $promptText -Default $false)) {
        Write-Status "Aborted." -Level Warning
        return
    }

    # Step 8: Execute
    Write-Host ""

    $schedule = @{ startDateTime = $startDate.ToString("o") }
    if ($hasEndDate) {
        $schedule['expiration'] = @{
            endDateTime = $endDate.ToString("o")
            type        = "afterDateTime"
        }
    } else {
        $schedule['expiration'] = @{ type = "noExpiration" }
    }

    $successCount = 0
    $failCount    = 0
    $failed       = @()

    foreach ($u in $toAssign) {
        Write-Status "Assigning $($u.DisplayName) ..." -Level Info
        $body = @{
            requestType = "adminAdd"
            assignment  = @{
                targetId           = $u.Id
                assignmentPolicyId = $chosenPolicy.Id
                accessPackageId    = $chosenPackage.Id
                schedule           = $schedule
            }
        }
        if ($justification) { $body['justification'] = $justification }

        try {
            New-MgEntitlementManagementAssignmentRequest -BodyParameter $body -ErrorAction Stop | Out-Null
            Write-Status "  $($u.DisplayName) assigned." -Level Success
            $successCount++
            continue
        } catch {
            $raw = $_.Exception.Message
            $clean = ($raw -replace '^\s*\[[^\]]+\]\s*:\s*','').Trim()

            if ($clean -match 'already an existing open request') {
                Write-Status "  $($u.DisplayName) — searching for the blocking request ..." -Level Info
                $allReqs = @()
                try {
                    $reqUri = "/v1.0/identityGovernance/entitlementManagement/assignmentRequests?`$filter=accessPackage/id eq '$($chosenPackage.Id)'&`$expand=target&`$top=999"
                    $reqResp = Invoke-MgGraphRequest -Method GET -Uri $reqUri -ErrorAction Stop
                    $allReqs = @($reqResp.value)
                } catch {
                    # Some tenants 403 on the requests endpoint — fall through to debug section below
                }

                # Match by id / objectId / email — the schema is inconsistent across tenants
                $userMatches = @($allReqs | Where-Object {
                    $t = $_.target
                    if (-not $t) { return $false }
                    ($t.id       -and $t.id       -eq $u.Id) -or
                    ($t.objectId -and $t.objectId -eq $u.Id) -or
                    ($t.email    -and ($t.email -ieq $u.UserPrincipalName -or ($u.Mail -and $t.email -ieq $u.Mail)))
                })

                # Prefer a non-terminal one; otherwise just the most recent
                $stuck = $userMatches |
                    Where-Object {
                        $s = ($_.state ?? '').ToString().ToLowerInvariant()
                        $s -notin @('delivered','failed','denied','canceled','cancelled')
                    } |
                    Sort-Object @{Expression={$_.createdDateTime}; Descending=$true} |
                    Select-Object -First 1

                if (-not $stuck) {
                    if ($userMatches.Count -gt 0) {
                        Write-Host "    ${ESC}[33mFound $($userMatches.Count) past request(s) for this user, all already in terminal states:${ESC}[0m"
                        foreach ($r in $userMatches | Sort-Object @{Expression={$_.createdDateTime}; Descending=$true} | Select-Object -First 5) {
                            Write-Host "    ${ESC}[90m  · state=$($r.state)  created=$($r.createdDateTime)  id=$($r.id)${ESC}[0m"
                        }
                        Write-Host "    ${ESC}[33mThe blocking record may be on a different access package or hidden by RBAC.${ESC}[0m"
                    } elseif ($allReqs.Count -gt 0) {
                        Write-Host "    ${ESC}[90mPulled $($allReqs.Count) requests for this package; none matched this user's id/objectId/email.${ESC}[0m"
                    } else {
                        Write-Host "    ${ESC}[90mCould not list requests for this package (permission or filter issue).${ESC}[0m"
                    }
                    Write-Status "  $($u.DisplayName) — manual cleanup needed: open the portal, find the user's open request on this package, cancel it." -Level Error
                    $failCount++; $failed += $u
                    continue
                }

                Write-Host "    ${ESC}[33mFound stuck request — state=$($stuck.state), id=$($stuck.id)${ESC}[0m"
                if (Show-Confirmation -Prompt "    Cancel it and retry assignment?" -Default $true) {
                    try {
                        Invoke-MgGraphRequest -Method POST -Uri "/v1.0/identityGovernance/entitlementManagement/assignmentRequests/$($stuck.id)/cancel" -ErrorAction Stop | Out-Null
                        Start-Sleep -Seconds 2
                        New-MgEntitlementManagementAssignmentRequest -BodyParameter $body -ErrorAction Stop | Out-Null
                        Write-Status "  $($u.DisplayName) assigned (stuck request canceled first)." -Level Success
                        $successCount++
                    } catch {
                        $r2 = ($_.Exception.Message -replace '^\s*\[[^\]]+\]\s*:\s*','').Trim()
                        Write-Status "  $($u.DisplayName) — cancel-and-retry failed: $r2" -Level Error
                        $failCount++; $failed += $u
                    }
                } else {
                    Write-Status "  $($u.DisplayName) — skipped (stuck request kept)." -Level Warning
                    $failCount++; $failed += $u
                }
                continue
            }

            $friendly = switch -Regex ($clean) {
                'already (has|have).*assignment'             { 'already has this access package.' ; break }
                'AccessPackageAssignmentPolicyNotFound'      { 'the chosen policy is no longer valid.' ; break }
                'NotAllowedByRequestor|requestor.*not allow' { "you don't have permission to submit this request." ; break }
                'TargetNotFound|user.*not found'             { 'user could not be found in the directory.' ; break }
                default                                      { $clean }
            }
            Write-Status "  $($u.DisplayName) — skipped: $friendly" -Level Error
            $failCount++
            $failed += $u
        }
    }

    Write-Host ""
    Write-Host "  ${ESC}[36m─────────────────────────────────────────────────${ESC}[0m"
    Write-Status "Done. $successCount succeeded, $failCount failed." -Level $(if ($failCount -eq 0) { 'Success' } else { 'Warning' })

    # Cooling-off period so assignments can propagate, then auto-refresh
    if ($successCount -gt 0) {
        Start-CoolingOffCountdown -Seconds 180
        Show-PackageAssignments `
            -AccessPackageId $chosenPackage.Id `
            -AssignmentPolicyId $chosenPolicy.Id `
            -PackageName $chosenPackage.DisplayName `
            -PolicyName $chosenPolicy.DisplayName
    } else {
        # Step 9: Offer to view all assigned users (no new assignments were made)
        Write-Host ""
        if (Show-Confirmation -Prompt "View all users assigned to this access package?" -Default $false) {
            Show-PackageAssignments `
                -AccessPackageId $chosenPackage.Id `
                -AssignmentPolicyId $chosenPolicy.Id `
                -PackageName $chosenPackage.DisplayName `
                -PolicyName $chosenPolicy.DisplayName
        }
    }
}

Export-ModuleMember -Function Start-AccessPackageOnDemand, Set-AccessPackageConfig, Get-AccessPackageConfig, Clear-AccessPackageConfig
