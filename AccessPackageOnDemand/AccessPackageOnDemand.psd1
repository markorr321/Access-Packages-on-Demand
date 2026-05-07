@{
    RootModule        = 'AccessPackageOnDemand.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'b6bedcdd-d518-4326-a6a6-cdcdc063d80a'
    Author            = 'Mark Orr'
    Copyright         = '(c) 2026 Mark Orr. All rights reserved.'
    Description       = 'Interactive on-demand assignment of users to Entra ID Access Packages via Microsoft Graph. Includes a configurable business justification picker, stuck-request recovery, assignment cooling-off countdown, and live assignments view.'
    PowerShellVersion = '7.0'

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
            ReleaseNotes             = 'v1.0.0 — Initial release. Interactive TUI for on-demand Access Package assignment with configurable business justification options, stuck-request recovery, cooling-off countdown, and live assignments view.'
            ExternalModuleDependencies = @(
                'Microsoft.Graph.Authentication',
                'Microsoft.Graph.Identity.Governance',
                'Microsoft.Graph.Users'
            )
        }
    }
}
