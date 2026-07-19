@{
    RootModule        = 'AccessPackageOnDemand.psm1'
    ModuleVersion     = '1.0.2'
    GUID              = 'b6bedcdd-d518-4326-a6a6-cdcdc063d80a'
    Author            = 'Mark Orr'
    Copyright         = '(c) 2026 Mark Orr. All rights reserved.'
    Description       = 'Interactive on-demand assignment of users to Entra ID Access Packages via Microsoft Graph. Includes a configurable business justification picker, stuck-request recovery, assignment cooling-off countdown, and live assignments view.'
    PowerShellVersion = '7.0'

    RequiredModules   = @(
        @{ ModuleName = 'Microsoft.Graph.Authentication';       ModuleVersion = '2.0.0' }
        @{ ModuleName = 'Microsoft.Graph.Identity.Governance';  ModuleVersion = '2.0.0' }
        @{ ModuleName = 'Microsoft.Graph.Users';                ModuleVersion = '2.0.0' }
    )

    FunctionsToExport = @(
        'Start-AccessPackageOnDemand',
        'Set-AccessPackageConfig',
        'Get-AccessPackageConfig',
        'Clear-AccessPackageConfig',
        'Set-AccessPackageJustificationOptions',
        'Get-AccessPackageJustificationOptions',
        'Clear-AccessPackageJustificationOptions',
        'Set-AppRegistrationConfig',
        'Get-AppRegistrationConfig',
        'Clear-AppRegistrationConfig'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData = @{
        PSData = @{
            Tags                     = @(
                'Entra', 'AzureAD', 'AccessPackages', 'EntitlementManagement',
                'Graph', 'MicrosoftGraph', 'Intune', 'TUI', 'OnDemand',
                'IdentityGovernance', 'PowerShell', 'Windows'
            )
            ProjectUri               = 'https://github.com/markorr321/Access-Packages-on-Demand'
            LicenseUri               = 'https://github.com/markorr321/Access-Packages-on-Demand/blob/main/AccessPackageOnDemand/LICENSE'
            ReleaseNotes             = 'v1.0.2 — Added a sign-in mode picker for first-time users, Tenant ID configuration for custom app registrations, streamlined justification setup with improved prompting, and enhanced authentication diagnostics. Builds on the interactive TUI for on-demand Access Package assignment with configurable business justification options, stuck-request recovery, cooling-off countdown, and live assignments view.'
        }
    }
}
