@{
    RootModule        = 'Jev.psm1'
    ModuleVersion     = '0.4.0'
    GUID              = '8b4efb8e-e7e3-4cc8-82ab-ad9314c2980a'
    Author            = 'Jev contributors'
    CompanyName       = ''
    Copyright         = '(c) 2026 Doug Finke'
    Description       = 'Turn unstructured input into consistent, structured decisions from PowerShell.'
    PowerShellVersion = '7.0'
    FunctionsToExport = @('New-JevQuestion', 'New-JevYesNoQuestion', 'Invoke-Jev', 'Test-Jev', 'Select-Jev', 'Add-JevAnnotation', 'Get-JevRanking', 'Find-Jev', 'Add-JevTag', 'Get-JevChoice', 'Get-JevScore')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags          = @('PowerShell', 'Decisions', 'AI', 'Questions', 'Automation', 'TypeSafe', 'Jev')
            ProjectUri    = 'https://github.com/dfinke/Jev'
            RepositoryUri = 'https://github.com/dfinke/Jev'
            LicenseUri    = 'https://github.com/dfinke/Jev/blob/main/LICENSE'
            IconUri       = 'https://raw.githubusercontent.com/dfinke/Jev/main/assets/jev-icon.png'
            ReleaseNotes  = 'Adds Get-JevRanking for semantic ranking, Find-Jev for comparative search, Add-JevTag for multi-label tagging, and compact Get-JevChoice and Get-JevScore commands. Includes pipeline examples for prioritizing replies, finding a checkout failure cause, tagging an inbox, routing requests, and scoring urgency.'
        }
    }
}
