@{
    RootModule        = 'Jev.psm1'
    ModuleVersion     = '0.2.0'
    GUID              = '8b4efb8e-e7e3-4cc8-82ab-ad9314c2980a'
    Author            = 'Jev contributors'
    CompanyName       = ''
    Copyright         = '(c) 2026 Doug Finke'
    Description       = 'Turn unstructured input into consistent, structured decisions from PowerShell.'
    PowerShellVersion = '7.0'
    FunctionsToExport = @('New-JevQuestion', 'New-JevYesNoQuestion', 'Invoke-Jev')
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
            ReleaseNotes  = 'Adds New-JevYesNoQuestion, array .Jev() support, Invoke-Jev -AsJson, and new examples.'
        }
    }
}
