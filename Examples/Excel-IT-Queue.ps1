#requires -Modules ImportExcel

Import-Module (Join-Path $PSScriptRoot '..' 'Jev.psd1') -Force

$xlsx = "$PSScriptRoot\..\data\IT-Operations-Queue.xlsx"

@(Import-Excel $xlsx -WorksheetName 'IT Queue').Jev(
    'Which request should IT investigate today because waiting could disrupt a time-sensitive business process?'
) | Sort-Object decision -Descending |
Format-Table Ticket, Service, UsersAffected, Deadline, decision -AutoSize
