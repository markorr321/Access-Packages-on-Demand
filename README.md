# Access-Package-OnDemand

A PowerShell module for **on-demand assignment** of users to Entra ID Access Packages via Microsoft Graph.

[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/Access-Package-OnDemand.svg?label=PowerShell%20Gallery)](https://www.powershellgallery.com/packages/Access-Package-OnDemand)
[![Downloads](https://img.shields.io/powershellgallery/dt/Access-Package-OnDemand.svg)](https://www.powershellgallery.com/packages/Access-Package-OnDemand)
![PowerShell](https://img.shields.io/badge/PowerShell-7+-blue.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

> Published on the [PowerShell Gallery](https://www.powershellgallery.com/packages/Access-Package-OnDemand). Install with `Install-Module -Name Access-Package-OnDemand`.

## Features

- Assign one user, or many users at once, by email address
- Pre-configure the access packages this tool is allowed to manage (no need to browse the directory each run)
- Detects existing assignments and reports them inline (`already has access` / `not found` / `ready to assign`)
- Configurable business justification options plus a custom free-text entry
- Auto-computes assignment end date from the policy's max duration — no date prompts
- Auto-recovery for stuck "open request" errors: finds the orphaned request, offers to cancel and retry
- Cross-platform browser-based sign-in (MSAL) — works on Windows, macOS, and Linux
- Optional custom app registration (Client ID / Tenant ID) for tenant-scoped consent or conditional-access-targeted apps
- 3-minute cooling-off countdown after a successful batch — lets assignments propagate before reviewing
- Auto-refresh of the current assignments view once the countdown completes
- "Run again" loop so you can do back-to-back assignments without re-authenticating

## Install

```powershell
Install-Module -Name Access-Package-OnDemand -Scope CurrentUser
```

This pulls in the required Microsoft Graph modules automatically. To update later:

```powershell
Update-Module -Name Access-Package-OnDemand
```

## Quick Start

```powershell
# 1. First-time setup — register the access packages this tool will manage
Set-AccessPackageConfig

# 2. Run the tool
Start-AccessPackageOnDemand
```

The module is auto-loaded from the gallery install location — no `Import-Module` path needed.

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
| `Set-AppRegistrationConfig` | Configure a custom Entra app registration (Client ID / Tenant ID) for sign-in |
| `Get-AppRegistrationConfig` | Show the configured app registration, if any |
| `Clear-AppRegistrationConfig` | Revert to the default Microsoft public client |

## Setup

### 1. Install the module

```powershell
Install-Module -Name Access-Package-OnDemand -Scope CurrentUser
```

The required Microsoft Graph modules (`Microsoft.Graph.Authentication`, `Microsoft.Graph.Identity.Governance`, `Microsoft.Graph.Users`) are installed as dependencies. If you prefer to install them explicitly:

```powershell
Install-Module Microsoft.Graph.Authentication, Microsoft.Graph.Identity.Governance, Microsoft.Graph.Users -Scope CurrentUser -Force
```

### 2. Configure the access packages this tool will manage

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

### 3. (Optional) Use your own app registration

By default the module signs in against the Microsoft Graph PowerShell public client. If your tenant requires a specific app (for conditional access or tenant-scoped consent), register one:

```powershell
Set-AppRegistrationConfig
```

You'll be prompted for a **Client ID** (required) and **Tenant ID** (optional). Run `Clear-AppRegistrationConfig` to revert to the default client.

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
5. **Justification** — choose from your configured canned options or type custom text. Required, can't be blank.
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
    { "DisplayName": "Autopilot Self Service",      "Id": "473b1caa-c098-40cc-9fb4-9293dbd5de0d" },
    { "DisplayName": "Microsoft Intune Enrollment", "Id": "a1b2c3d4-..." }
  ],
  "JustificationOptions": [
    "Project onboarding access",
    "Temporary incident response access"
  ],
  "AppRegistration": {
    "ClientId": "00000000-0000-0000-0000-000000000000",
    "TenantId": "11111111-1111-1111-1111-111111111111"
  }
}
```

Edit by hand if you prefer, or use `Set-AccessPackageConfig` / `Set-AppRegistrationConfig`.

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
- Microsoft Graph PowerShell modules (installed automatically as dependencies):
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

## Links

- [PowerShell Gallery](https://www.powershellgallery.com/packages/Access-Package-OnDemand)
- [GitHub](https://github.com/markorr321/Access-Packages-on-Demand)

## License

MIT

## Author

Mark Orr
