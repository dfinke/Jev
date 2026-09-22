@{
    RootModule        = 'Jev.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = '8b4efb8e-e7e3-4cc8-82ab-ad9314c2980a'
    Author            = 'Jev contributors'
    CompanyName       = ''
    Copyright         = '(c) Jev contributors. All rights reserved.'
    Description       = 'Turn unstructured input into consistent, structured decisions from PowerShell.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @('New-JevQuestion', 'New-JevChoice', 'Invoke-Jev')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags       = @('PowerShell', 'Decisions', 'AI', 'Questions', 'Automation')
            ProjectUri = 'https://github.com/dfinke/Jev'
        }
    }
}
