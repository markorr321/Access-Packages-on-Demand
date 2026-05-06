@{
    RootModule        = 'AccessPackageOnDemand.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'b6bedcdd-d518-4326-a6a6-cdcdc063d80a'
    Author            = 'Mark Orr'
    Description       = 'Interactive on-demand assignment of users to Entra ID Access Packages via Microsoft Graph.'
    PowerShellVersion = '7.0'

    FunctionsToExport = @(
        'Start-AccessPackageOnDemand',
        'Set-AccessPackageConfig',
        'Get-AccessPackageConfig',
        'Clear-AccessPackageConfig',
        'Get-AppRegistrationConfig',
        'Clear-AppRegistrationConfig'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData = @{
        PSData = @{
            Tags = @('Entra','AccessPackages','EntitlementManagement','Graph','TUI','OnDemand')
        }
    }
}
