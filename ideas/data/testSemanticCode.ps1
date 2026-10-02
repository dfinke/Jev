#requires -Version 7.0

<#
.SYNOPSIS
    Sample functions for testing semantic code linting with Invoke-Jev.
#>

function Get-UserConfig {
    [CmdletBinding()]
    param([string]$Username)

    # Clean, focused single-responsibility function
    $configPath = "C:\Configs\$Username.json"
    if (Test-Path $configPath) {
        return Get-Content $configPath | ConvertFrom-Json
    }
    return $null
}

function Get-ActiveDirectoryReport {
    [CmdletBinding()]
    param([string]$Domain)

    # Misleading Name & Side Effect: A 'Get' function that deletes logs and restarts a service!
    Write-Host "Fetching AD Report for $Domain..."
    
    # Hidden side effect
    Remove-Item -Path "C:\Logs\*.log" -Force -ErrorAction SilentlyContinue
    Restart-Service -Name "W3SVC" -Force

    return [PSCustomObject]@{ Domain = $Domain; Status = "Purged and Processed" }
}

function Do-StuffAndProcessData {
    [CmdletBinding()]
    param($InputData)

    # Non-standard verb, vague name, and bloated multi-responsibility
    # Responsibility 1: Parse input
    $parsed = $InputData -split "," | Where-Object { $_ -ne "" }

    # Responsibility 2: Call REST API
    $apiResult = Invoke-RestMethod -Uri "https://api.example.com/sync" -Method Post -Body ($parsed | ConvertTo-Json)

    # Responsibility 3: Write out to CSV on disk
    $apiResult | Export-Csv -Path "C:\Exports\sync_result.csv" -NoTypeInformation

    # Responsibility 4: Send notification email
    Send-MailMessage -To "admin@example.com" -Subject "Sync Complete" -Body "Done" -SmtpServer "mail.example.com"
}

function Sync-CustomerDatabase {
    [CmdletBinding()]
    param([string]$ConnectionString)

    # Anti-Pattern: Swallowing errors silently in a catch block
    try {
        $connection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
        $connection.Open()
        # Simulate db work
        Start-Sleep -Seconds 1
    }
    catch {
        # Silent error swallowing — no logging, no rethrow
        $null = $_
    }
}

function ConvertTo-UnixTimestamp {
    [CmdletBinding()]
    param([datetime]$DateTime)

    # Clean, pure utility function
    return [DateTimeOffset]::new($DateTime).ToUnixTimeSeconds()
}