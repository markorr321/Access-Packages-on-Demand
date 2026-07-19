# AccessPackageOnDemand

A PowerShell module for **on-demand assignment** of users to Entra ID Access Packages via Microsoft Graph.

![PowerShell](https://img.shields.io/badge/PowerShell-7+-blue.svg)
![Platform](https://img.shields.io/badge/Platform-Windows-lightgrey.svg)

## Features

- Assign one user, or many users at once, by email address
- Pre-configure the access packages this tool is allowed to manage (no need to browse the directory each run)
- Detects existing assignments and reports them inline (`already has access` / `not found` / `ready to assign`)
- Configurable business justification options plus a custom free-text entry
- Auto-computes assignment end date from the policy's max duration — no date prompts
- Auto-recovery for stuck "open request" errors: finds the orphaned request, offers to cancel and retry
- **3-minute cooling-off countdown** after a successful batch — lets assignments propagate before reviewing
- **Auto-refresh** of the current assignments view after the countdown completes
- Live assignments view with refresh — active assignments shown as **active** (green), in-flight requests shown separately
- "Run again" loop so you can do back-to-back assignments without re-authenticating

## Quick Start

```powershell
# 1. Import the module
Import-Module 'C:\Projects\Access Packages\AccessPackageOnDemand'

# 2. First-time setup — register the access packages this tool will manage
Set-AccessPackageConfig

# 3. Run the tool
Start-AccessPackageOnDemand
```

## Cmdlets

| Cmdlet | Description |
|--------|-------------|
| `Start-AccessPackageOnDemand` | Launch the interactive TUI (auth → pick package → enter emails → justify → assign) |
| `Set-AccessPackageConfig` | Interactive menu to add / remove / replace the configured access packages |
| `Get-AccessPackageConfig` | List the access packages currently configured |
| `Clear-AccessPackageConfig` | Delete the saved configuration |
| `Set-AccessPackageJustificationOptions` | Set the canned business justification options |
| `Get-AccessPackageJustificationOptions` | Show the effective canned justification options |
| `Clear-AccessPackageJustificationOptions` | Remove custom options and revert to defaults |

## Setup

### 1. Install the Microsoft Graph modules

```powershell
Install-Module Microsoft.Graph.Authentication, Microsoft.Graph.Identity.Governance, Microsoft.Graph.Users -Scope CurrentUser -Force
```

### 2. Import this module

```powershell
Import-Module 'C:\Projects\Access Packages\AccessPackageOnDemand' -Force
```

To make this permanent (so you don't need the full path):

```powershell
[Environment]::SetEnvironmentVariable(
    'PSModulePath',
    "C:\Projects\Access Packages;" + [Environment]::GetEnvironmentVariable('PSModulePath','User'),
    'User'
)
```

After restarting PowerShell, `Import-Module AccessPackageOnDemand` works from anywhere.

### 3. Configure the access packages this tool will manage

```powershell
Set-AccessPackageConfig
```

For each package, you'll be prompted for:

- **Object ID** — the access package GUID. Get it from the Entra portal:
  *Identity Governance → Entitlement management → Access packages → click the package → copy the ID.*
- **Friendly name** — anything you want to show in the picker.

Configuration is saved to `%LOCALAPPDATA%\AccessPackageOnDemand\config.json`.

Verify with:

```powershell
Get-AccessPackageConfig
```

## Daily Use

```powershell
Start-AccessPackageOnDemand
```

What happens:

1. **Auth** — silent if you have a cached Graph token; otherwise opens a browser sign-in. Required scopes: `EntitlementManagement.ReadWrite.All`, `User.Read.All`.
2. **Package** — auto-selected if only one is configured; otherwise picker.
3. **Policy** — auto-selected if the package has one policy.
4. **Emails** — type one address, or several separated by commas / spaces / semicolons. Each email is resolved and labeled inline:
   - `→ ready to assign` (green)
   - `→ already has access` (yellow)
   - `→ not found` (red)
5. **Justification** — choose from pre-built options or enter a custom reason. Required, can't be blank.
6. **Confirm** → submits the assignment for each user. Start = now, end = policy max (auto).
7. **Cooling-off** — a 3-minute countdown runs automatically so assignments have time to propagate through the directory. Press `Ctrl+C` to skip.
8. **Auto-refresh** — the current assignments view loads automatically after the countdown, showing each user's status as `active` (green), `delivering` (cyan), or `partial` (yellow).
9. **Run again or exit** — `R` loops back without re-authenticating.

## Business Justification

When assigning users you will be prompted to pick a justification. The numbered options come from your saved configuration:

```
  Business justification (required)
    1  Project onboarding access
    2  Temporary incident response access
    3  Contractor day-1 access
    C  Custom (type your own)
```

Select a number for a saved option, or `C` to type any free-text reason.

Set your own canned responses:

```powershell
Set-AccessPackageJustificationOptions
```

You will be prompted for each option one at a time. Each prompt shows `(blank to save)` — press Enter on a blank line to finish and save.

You can also pass an array directly:

```powershell
Set-AccessPackageJustificationOptions -Options @(
  'Project onboarding access',
  'Temporary incident response access',
  'Contractor day-1 access'
)
```

View current options:

```powershell
Get-AccessPackageJustificationOptions
```

Revert to built-in defaults:

```powershell
Clear-AccessPackageJustificationOptions
```

Optional one-off override at run time:

```powershell
Start-AccessPackageOnDemand -JustificationOptions @('Break/fix support', 'User migration')
```

## Configuration File

```
%LOCALAPPDATA%\AccessPackageOnDemand\config.json
```

Shape:

```json
{
  "Packages": [
    { "DisplayName": "Autopilot Self Service",      "Id": "00000000-0000-0000-0000-000000000000" },
    { "DisplayName": "Microsoft Intune Enrollment", "Id": "a1b2c3d4-..." }
  ],
  "JustificationOptions": [
    "Project onboarding access",
    "Temporary incident response access"
  ]
}
```

Edit by hand if you prefer, or use `Set-AccessPackageConfig`.

## Stuck-Request Recovery

If a previous attempt left a half-finished assignment request in the API, you'll see the friendly message:

```
Pat Mahomes — has a pending request already
Found stuck request — state=submitted, id=abc-123
Cancel it and retry assignment? [Y/n]
```

Hit `Y` and the tool cancels the orphaned request, waits 2 seconds, and re-submits — no portal trip required.

## Requirements

- PowerShell 7.0+
- Microsoft Graph PowerShell modules:
  - `Microsoft.Graph.Authentication`
  - `Microsoft.Graph.Identity.Governance`
  - `Microsoft.Graph.Users`
- Permissions on the signed-in account:
  - `EntitlementManagement.ReadWrite.All` (delegated)
  - `User.Read.All` (delegated)
- Directory role that can manage access package assignments (e.g. *Identity Governance Administrator*, or the package's assigned *Catalog owner* / *Access Package Manager*).

## Troubleshooting

| Symptom | Fix |
|---|---|
| `No access packages configured.` | Run `Set-AccessPackageConfig` and add at least one package. |
| `Failed to load policies: BadRequest` | The saved package GUID isn't a real access package. `Clear-AccessPackageConfig`, then `Set-AccessPackageConfig` and re-paste the ID from the portal. |
| `Authentication failed` | Sign-in account doesn't have a directory role with access package management rights. |
| Assignment shows `delivering` and stays there | Graph backend is still processing — the auto-refresh view opens after the 3-minute countdown. Hit `R` to refresh again if needed. |
| `→ not found` for a known user | The email may not be the user's UPN or primary `mail` address. Try the UPN explicitly. |

## License

MIT

## Author

Mark Orr

## Quick Start

```powershell
# 1. Import the module
Import-Module 'C:\Projects\Access Packages\AccessPackageOnDemand'

# 2. First-time setup — register the access packages this tool will manage
Set-AccessPackageConfig

# 3. Run the tool
Start-AccessPackageOnDemand
```

## Cmdlets

| Cmdlet | Description |
|--------|-------------|
| `Start-AccessPackageOnDemand` | Launch the interactive TUI (auth → pick package → enter emails → justify → assign) |
| `Set-AccessPackageConfig` | Interactive menu to add / remove / replace the configured access packages |
| `Get-AccessPackageConfig` | List the access packages currently configured |
| `Clear-AccessPackageConfig` | Delete the saved configuration |

## Setup

### 1. Install the Microsoft Graph modules

```powershell
Install-Module Microsoft.Graph.Authentication, Microsoft.Graph.Identity.Governance, Microsoft.Graph.Users -Scope CurrentUser -Force
```

### 2. Import this module

```powershell
Import-Module 'C:\Projects\Access Packages\AccessPackageOnDemand' -Force
```

To make this permanent (so you don't need the full path):

```powershell
[Environment]::SetEnvironmentVariable(
    'PSModulePath',
    "C:\Projects\Access Packages;" + [Environment]::GetEnvironmentVariable('PSModulePath','User'),
    'User'
)
```

After restarting PowerShell, `Import-Module AccessPackageOnDemand` works from anywhere.

### 3. Configure the access packages this tool will manage

```powershell
Set-AccessPackageConfig
```

For each package, you'll be prompted for:

- **Object ID** — the access package GUID. Get it from the Entra portal:
  *Identity Governance → Entitlement management → Access packages → click the package → copy the ID.*
- **Friendly name** — anything you want to show in the picker.

Configuration is saved to `%LOCALAPPDATA%\AccessPackageOnDemand\config.json`.

Verify with:

```powershell
Get-AccessPackageConfig
```

## Daily Use

```powershell
Start-AccessPackageOnDemand
```

What happens:

1. **Auth** — silent if you have a cached Graph token; otherwise opens a browser sign-in. Required scopes: `EntitlementManagement.ReadWrite.All`, `User.Read.All`.
2. **Package** — auto-selected if only one is configured; otherwise picker.
3. **Policy** — auto-selected if the package has one policy.
4. **Emails** — type one address, or several separated by commas / spaces / semicolons. Each email is resolved and labeled inline:
   - `→ ready to assign` (green)
   - `→ already has access` (yellow)
   - `→ not found` (red)
5. **Justification** — required, can't be blank.
6. **Confirm** → submits the assignment for each user. Start = now, end = policy max (auto).
7. **Optional review** — view current assignments. `R` to refresh until everyone shows `delivered`.
8. **Run again or exit** — `R` loops back without re-authenticating.

## Configuration File

```
%LOCALAPPDATA%\AccessPackageOnDemand\config.json
```

Shape:

```json
{
  "Packages": [
    { "DisplayName": "Autopilot Self Service",      "Id": "00000000-0000-0000-0000-000000000000" },
    { "DisplayName": "Microsoft Intune Enrollment", "Id": "a1b2c3d4-..." }
  ]
}
```

Edit by hand if you prefer, or use `Set-AccessPackageConfig`.

## Stuck-Request Recovery

If a previous attempt left a half-finished assignment request in the API, you'll see the friendly message:

```
Pat Mahomes — has a pending request already
Found stuck request — state=submitted, id=abc-123
Cancel it and retry assignment? [Y/n]
```

Hit `Y` and the tool cancels the orphaned request, waits 2 seconds, and re-submits — no portal trip required.

## Requirements

- PowerShell 7.0+
- Microsoft Graph PowerShell modules:
  - `Microsoft.Graph.Authentication`
  - `Microsoft.Graph.Identity.Governance`
  - `Microsoft.Graph.Users`
- Permissions on the signed-in account:
  - `EntitlementManagement.ReadWrite.All` (delegated)
  - `User.Read.All` (delegated)
- Directory role that can manage access package assignments (e.g. *Identity Governance Administrator*, or the package's assigned *Catalog owner* / *Access Package Manager*).

## Troubleshooting

| Symptom | Fix |
|---|---|
| `No access packages configured.` | Run `Set-AccessPackageConfig` and add at least one package. |
| `Failed to load policies: BadRequest` | The saved package GUID isn't a real access package. `Clear-AccessPackageConfig`, then `Set-AccessPackageConfig` and re-paste the ID from the portal. |
| `Authentication failed` | Sign-in account doesn't have a directory role with access package management rights. |
| Assignment shows `delivering` and stays there | Graph backend is still processing — hit `R` on the assignments view a few seconds later. Most adminAdds finish within ~30s. |
| `→ not found` for a known user | The email may not be the user's UPN or primary `mail` address. Try the UPN explicitly. |

## License

MIT

## Author

Mark Orr
