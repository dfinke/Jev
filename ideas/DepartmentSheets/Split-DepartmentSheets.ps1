#requires -Version 7.0
#requires -Modules ImportExcel

<#
.SYNOPSIS
    Classifies unlabeled Excel sheets with Jev and writes one workbook per sheet.

.DESCRIPTION
    Reads each worksheet with ImportExcel. Sends the column headers and the
    first few rows to Jev, which chooses what the sheet relates to. PowerShell
    then writes every row from that sheet into its own workbook. The workbook
    file and its worksheet use the label Jev returned.

    Jev Choice questions return one of the supplied labels. They do not invent
    a free-text file name. Edit the label table in this script to change the
    names the example can produce. Unknown, or a choice below
    -ConfidenceThreshold, is not used as a name. Those sheets are written as
    Review-<original sheet name> so a person can check them.

    Set TYPESAFE_API_KEY before classifying. -Mock exercises the file split
    without calling the API. The local mock matches label text; it does not
    read the rows the way Jev does, so a mock run usually writes Review- names.

.EXAMPLE
    .\Split-DepartmentSheets.ps1 -CreateSample

.EXAMPLE
    .\Split-DepartmentSheets.ps1

.EXAMPLE
    .\Split-DepartmentSheets.ps1 -SampleRows 5 -ConfidenceThreshold 0.5 -OutputDirectory .\named
#>
[CmdletBinding()]
param(
    [string] $Path = (Join-Path $PSScriptRoot 'Mixed-Departments.xlsx'),

    [string] $OutputDirectory = (Join-Path $PSScriptRoot 'out'),

    [ValidateRange(1, 10)]
    [int] $SampleRows = 3,

    [ValidateRange(0, 1)]
    [double] $ConfidenceThreshold = 0.6,

    [switch] $CreateSample,

    [switch] $Mock,

    [switch] $Force
)

function ConvertTo-JevCellValue {
    param($Value)

    if ($null -eq $Value) { return $null }
    if ($Value -is [datetime]) {
        if ($Value.TimeOfDay -eq [timespan]::Zero) {
            return $Value.ToString('yyyy-MM-dd')
        }
        return $Value.ToString('yyyy-MM-dd HH:mm')
    }
    return $Value
}

function Get-SafeSheetLabel {
    param(
        [Parameter(Mandatory)]
        [string] $Label
    )

    $clean = ($Label -replace '[\\/:*?"<>|\[\]]', ' ').Trim()
    $clean = ($clean -replace '\s+', ' ').Trim("'").TrimEnd('.')
    if ([string]::IsNullOrWhiteSpace($clean)) {
        $clean = 'Unclassified'
    }
    if ($clean.Length -gt 31) {
        $clean = $clean.Substring(0, 31).Trim().TrimEnd('.')
    }
    return $clean
}

function Get-UniqueSheetLabel {
    param(
        [Parameter(Mandatory)]
        [string] $Label,

        [Parameter(Mandatory)]
        [hashtable] $Used
    )

    $name = Get-SafeSheetLabel -Label $Label
    $suffixNumber = 2
    while ($Used.ContainsKey($name)) {
        $suffix = "-$suffixNumber"
        $base = Get-SafeSheetLabel -Label $Label
        if (($base.Length + $suffix.Length) -gt 31) {
            $base = $base.Substring(0, 31 - $suffix.Length).Trim().TrimEnd('.')
        }
        $name = "$base$suffix"
        $suffixNumber++
    }

    $Used[$name] = $true
    return $name
}

function Set-SheetNumberFormats {
    param(
        $Worksheet,

        [Parameter(Mandatory)]
        [string[]] $Headers
    )

    for ($index = 0; $index -lt $Headers.Count; $index++) {
        $format = switch -Regex ($Headers[$index]) {
            'OpenedAt' { 'yyyy-mm-dd hh:mm'; break }
            'Date|Close|Scheduled' { 'yyyy-mm-dd'; break }
            'Amount|Salary' { '#,##0.00'; break }
            'WinProbability' { '0%' }
        }
        if ($format) {
            $Worksheet.Column($index + 1).Style.Numberformat.Format = $format
        }
    }
}

function ConvertFrom-DepartmentCsv {
    param(
        [Parameter(Mandatory)]
        [string] $Csv,

        [string[]] $DateColumns = @(),

        [string[]] $DateTimeColumns = @(),

        [string[]] $NumberColumns = @()
    )

    $rows = @(ConvertFrom-Csv -InputObject $Csv.Trim())
    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    foreach ($row in $rows) {
        foreach ($column in $DateColumns) {
            $row.$column = [datetime]::ParseExact([string] $row.$column, 'yyyy-MM-dd', $culture)
        }
        foreach ($column in $DateTimeColumns) {
            $row.$column = [datetime]::ParseExact([string] $row.$column, 'yyyy-MM-dd HH:mm', $culture)
        }
        foreach ($column in $NumberColumns) {
            $row.$column = [double] $row.$column
        }
    }
    return $rows
}

function New-MixedDepartmentWorkbook {
    param(
        [Parameter(Mandatory)]
        [string] $WorkbookPath,

        [switch] $Replace
    )

    $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($WorkbookPath)
    if (Test-Path -LiteralPath $resolved) {
        if (-not $Replace) {
            throw "Workbook already exists: $resolved. Pass -Force to replace it."
        }
        Remove-Item -LiteralPath $resolved -Force
    }

    $directory = Split-Path -Path $resolved -Parent
    if (-not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    # Sheet names stay sheet1-sheet5 on purpose. Do not add a department column.
    # The classifier has to infer the subject from headers and sample rows.
    $sheets = @(
        [pscustomobject]@{
            Name            = 'sheet1'
            DateColumns     = @('ScheduledDate')
            DateTimeColumns = @()
            NumberColumns   = @()
            Csv             = @'
WorkOrderId,Building,Floor,AssetTag,RequestType,RequestedBy,ScheduledDate,Status
WO-3188,Lakeside HQ,L2,AHU-14,Filter replacement,Nora Patel,2026-04-06,Scheduled
WO-3194,Lakeside HQ,L1,Badge-Reader-03,Access door fault,Chris Nguyen,2026-04-07,Open
WO-3201,West Annex,B1,Sump-Pump-2,Water alarm,Elena Vasquez,2026-04-07,In Progress
WO-3210,Lakeside HQ,L4,Conf-AV-12,Projector lamp,Jordan Blake,2026-04-08,Scheduled
WO-3216,South Warehouse,L1,Dock-Leveler-7,Safety inspection,Samir Haddad,2026-04-09,Open
WO-3222,Lakeside HQ,L3,Restroom-3B,Plumbing leak,Riley Brooks,2026-04-09,In Progress
WO-3230,West Annex,L2,Lighting-Panel-B,Ballast failure,Avery Cole,2026-04-10,Scheduled
WO-3238,South Warehouse,L1,HVAC-RTU-4,No heat,Morgan Ibarra,2026-04-10,Open
WO-3244,Lakeside HQ,L5,Carpet-5E,Stain removal,Quinn Adler,2026-04-13,Scheduled
WO-3251,West Annex,L1,Fire-Ext-18,Annual service,Harper Singh,2026-04-14,Open
'@
        }
        [pscustomobject]@{
            Name            = 'sheet2'
            DateColumns     = @('ExpectedClose')
            DateTimeColumns = @()
            NumberColumns   = @('Amount', 'WinProbability')
            Csv             = @'
OpportunityId,AccountName,Stage,Owner,ProductLine,Region,Amount,Currency,ExpectedClose,WinProbability
OPP-8841,Northwind Clinics,Discovery,Luis Ortega,Care Analytics,Central,42000,USD,2026-06-30,0.20
OPP-8856,Harbor and Pine,Proposal,Mina Cho,Field Service,West,128500,USD,2026-05-15,0.55
OPP-8862,Cobalt Freight,Negotiation,Luis Ortega,Route Optimizer,East,210000,USD,2026-04-28,0.70
OPP-8870,Brightline Schools,Qualification,Priya Nair,Campus Portal,South,36000,USD,2026-07-20,0.30
OPP-8877,Kepler Manufacturing,Proposal,Owen Grant,Plant Sensors,Central,96000,USD,2026-05-29,0.45
OPP-8884,Solace Hotels,Verbal Commit,Mina Cho,Guest Messaging,West,74000,USD,2026-04-22,0.80
OPP-8891,Red Kite Media,Discovery,Owen Grant,Campaign Studio,East,18500,USD,2026-08-04,0.15
OPP-8903,Atlas Municipal,Negotiation,Priya Nair,Citizen Requests,South,305000,USD,2026-06-12,0.60
OPP-8910,Fennel Grocery,Proposal,Luis Ortega,Inventory Forecast,Central,54000,USD,2026-05-08,0.50
OPP-8918,Ion Labs,Qualification,Mina Cho,Lab Scheduler,West,88000,USD,2026-07-01,0.35
'@
        }
        [pscustomobject]@{
            Name            = 'sheet3'
            DateColumns     = @()
            DateTimeColumns = @('OpenedAt')
            NumberColumns   = @()
            Csv             = @'
TicketId,OpenedAt,Requester,AffectedSystem,Priority,Status
INC-55210,2026-03-18 08:12,Devon Marsh,VPN Gateway,High,In Progress
INC-55218,2026-03-18 09:40,Sasha Bennett,Email Relay,Medium,Waiting on User
INC-55233,2026-03-18 11:05,Noel Kim,Laptop Imaging,Low,Open
INC-55241,2026-03-18 13:22,Camille Ortiz,Identity Provider,High,In Progress
INC-55255,2026-03-19 07:48,Elliot Ward,File Share,Medium,Open
INC-55260,2026-03-19 10:16,Farah Rahman,Badge Printer,Low,Resolved
INC-55274,2026-03-19 14:03,Gabe Hoffman,Wi-Fi Controller,High,In Progress
INC-55281,2026-03-19 15:37,Helena Cruz,CRM Sandbox,Medium,Waiting on Vendor
INC-55290,2026-03-20 08:55,Ivan Petrov,Password Reset Portal,Low,Open
INC-55302,2026-03-20 11:28,Jules Park,Backup Job,High,In Progress
'@
        }
        [pscustomobject]@{
            Name            = 'sheet4'
            DateColumns     = @('InvoiceDate', 'DueDate')
            DateTimeColumns = @()
            NumberColumns   = @('Amount')
            Csv             = @'
InvoiceNumber,VendorName,InvoiceDate,DueDate,Amount,Currency,CostCenter,PoNumber,PaymentStatus
INV-10442,Lumen Office Supply,2026-02-02,2026-03-04,1284.16,USD,CC-410,PO-7781,Open
INV-10458,Peak Cloud Hosting,2026-02-05,2026-03-07,6420.00,USD,CC-220,PO-7804,Approved
INV-10463,Harbor Legal LLP,2026-02-06,2026-03-08,3100.00,USD,CC-110,PO-7810,Open
INV-10471,Metro Courier,2026-02-09,2026-03-11,486.75,USD,CC-410,PO-7822,Paid
INV-10488,Cedar Catering,2026-02-11,2026-03-13,920.40,USD,CC-150,PO-7835,Approved
INV-10495,Northgrid Energy,2026-02-12,2026-03-14,8744.22,USD,CC-500,PO-7841,Open
INV-10502,Quill and Bind Printing,2026-02-16,2026-03-18,640.00,USD,CC-410,PO-7850,Paid
INV-10511,Vivid Staffing,2026-02-18,2026-03-20,15250.00,USD,CC-310,PO-7866,Approved
INV-10520,Alloy Sensors Inc,2026-02-20,2026-03-22,4388.90,USD,CC-220,PO-7874,Open
INV-10533,Bluebird Insurance,2026-02-24,2026-03-26,2190.00,USD,CC-110,PO-7888,Open
'@
        }
        [pscustomobject]@{
            Name            = 'sheet5'
            DateColumns     = @('HireDate')
            DateTimeColumns = @()
            NumberColumns   = @('AnnualSalary')
            Csv             = @'
EmployeeId,FullName,JobTitle,HireDate,WorkLocation,Manager,AnnualSalary
E-2044,Avery Chen,Total Rewards Analyst,2019-06-17,Austin,Morgan Hale,78500
E-2081,Benito Alvarez,Recruiter,2021-01-11,Chicago,Morgan Hale,81200
E-2110,Chloe Dubois,Benefits Analyst,2018-09-03,Austin,Morgan Hale,86400
E-2146,Derek Okonkwo,HR Business Partner,2016-04-25,Seattle,Robin Shaw,112000
E-2188,Esme Laurent,People Operations Coordinator,2023-02-14,Chicago,Robin Shaw,68400
E-2215,Farid Hassan,Compensation Analyst,2020-11-02,Seattle,Robin Shaw,97800
E-2240,Greta Novak,Talent Sourcer,2024-07-08,Austin,Morgan Hale,73600
E-2272,Hiro Tanaka,Employee Relations Partner,2017-03-19,Seattle,Robin Shaw,104500
E-2304,Imani Brooks,Onboarding Specialist,2022-08-29,Chicago,Morgan Hale,74200
E-2331,Jonah Petrov,Leave Administrator,2015-12-01,Austin,Robin Shaw,80100
'@
        }
    )

    foreach ($sheet in $sheets) {
        $rows = @(ConvertFrom-DepartmentCsv -Csv $sheet.Csv -DateColumns $sheet.DateColumns -DateTimeColumns $sheet.DateTimeColumns -NumberColumns $sheet.NumberColumns)
        $columnCount = @($rows[0].PSObject.Properties).Count
        if ($rows.Count -ne 10) {
            throw "$($sheet.Name) must have 10 data rows. Found $($rows.Count)."
        }
        if ($columnCount -lt 5 -or $columnCount -gt 10) {
            throw "$($sheet.Name) must have 5 to 10 columns. Found $columnCount."
        }
        $rows | Export-Excel -Path $resolved -WorksheetName $sheet.Name -AutoSize -BoldTopRow -FreezeTopRow
    }

    $package = Open-ExcelPackage -Path $resolved
    try {
        foreach ($sheet in $sheets) {
            $worksheet = $package.Workbook.Worksheets[$sheet.Name]
            $headers = @($worksheet.Cells[1, 1, 1, $worksheet.Dimension.End.Column].Value)
            Set-SheetNumberFormats -Worksheet $worksheet -Headers $headers
        }
    }
    finally {
        Close-ExcelPackage -ExcelPackage $package
    }

    $created = @(Get-ExcelSheetInfo -Path $resolved | Sort-Object Index)
    $expected = @($sheets.Name)
    $actual = @($created.Name)
    if (($actual -join ',') -ne ($expected -join ',')) {
        throw "Expected sheets $($expected -join ', '). Found $($actual -join ', ')."
    }

    foreach ($sheet in $sheets) {
        $imported = @(Import-Excel -Path $resolved -WorksheetName $sheet.Name)
        $columnCount = @($imported[0].PSObject.Properties).Count
        if ($imported.Count -ne 10 -or $columnCount -lt 5 -or $columnCount -gt 10) {
            throw "$($sheet.Name) was written with $($imported.Count) rows and $columnCount columns."
        }
        Write-Host ("{0,-8} {1,2} columns  {2,2} rows  {3}" -f $sheet.Name, $columnCount, $imported.Count, (($imported[0].PSObject.Properties.Name) -join ', '))
    }

    Write-Host "Unlabeled workbook: $resolved" -ForegroundColor Cyan
}

if ($CreateSample) {
    New-MixedDepartmentWorkbook -WorkbookPath $Path -Replace:$Force
    return
}

if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Workbook not found: $Path. Pass -Path, or run -CreateSample to build Mixed-Departments.xlsx."
}

if (-not $Mock -and [string]::IsNullOrWhiteSpace([string] $env:TYPESAFE_API_KEY)) {
    throw 'TYPESAFE_API_KEY is not set. Set it before classifying sheets, or pass -Mock to exercise the file split locally.'
}

Import-Module (Join-Path $PSScriptRoot '..\..\Jev.psd1') -Force

# These keys are the workbook and worksheet names. Keep Unknown as the
# fallback label. Other keys must already be valid Excel sheet names.
$criteria = [ordered]@{
    'Employee-Roster'        = 'People records: employee ids, names, job titles, hire dates, managers, work locations, or pay.'
    'Vendor-Invoices'        = 'Accounts payable: invoice numbers, vendors, invoice dates, due dates, amounts, purchase orders, cost centers, or payment status.'
    'Help-Desk-Tickets'      = 'IT support work: ticket or incident ids, opened times, requesters, affected systems, priority, or ticket status.'
    'Sales-Pipeline'         = 'Sales opportunities: opportunity ids, accounts, stages, owners, products, regions, amounts, expected close dates, or win probability.'
    'Facilities-Work-Orders' = 'Workplace operations: work order ids, buildings, floors, asset tags, maintenance request types, or scheduled site work.'
    Unknown                  = 'The headers and sample rows do not clearly match one of the other subjects.'
}

foreach ($label in @($criteria.Keys | Where-Object { $_ -ne 'Unknown' })) {
    $safe = Get-SafeSheetLabel -Label $label
    if ($safe -ne $label) {
        throw "Label '$label' is not a valid workbook or worksheet name. Use 1-31 characters, without \ / : * ? `" < > | [ ]"
    }
}

$question = New-JevQuestion -Name subject -Type Choice -Criteria $criteria -Instructions @'
The worksheet name is an unlabeled placeholder and is not evidence.
Using only the column headers and sample rows, choose the single subject this sheet relates to.
Choose Unknown when the sample does not clearly match one subject.
Do not invent a subject that is not listed.
'@

$sourcePath = (Resolve-Path -LiteralPath $Path).Path
$outputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDirectory)
if (Test-Path -LiteralPath $outputPath) {
    $existing = @(Get-ChildItem -LiteralPath $outputPath -Filter *.xlsx -File -ErrorAction SilentlyContinue)
    if ($existing.Count -gt 0 -and -not $Force) {
        throw "Output directory already contains workbooks: $outputPath. Pass -Force to replace the .xlsx files there, or choose a new -OutputDirectory."
    }
    if ($Force) {
        $existing | Remove-Item -Force
    }
}
else {
    New-Item -ItemType Directory -Path $outputPath -Force | Out-Null
}

$sheetNames = @(Get-ExcelSheetInfo -Path $sourcePath | Sort-Object Index | Where-Object { -not $_.Hidden } | Select-Object -ExpandProperty Name)
if ($sheetNames.Count -eq 0) {
    throw "No worksheets found in $sourcePath."
}

$usedNames = @{}
$summary = foreach ($sheetName in $sheetNames) {
    $rows = @(Import-Excel -Path $sourcePath -WorksheetName $sheetName -DataOnly)
    if ($rows.Count -eq 0) {
        Write-Warning "Skipped $sheetName because it has no data rows."
        continue
    }

    $headers = @($rows[0].PSObject.Properties.Name)
    $sample = @(
        foreach ($row in ($rows | Select-Object -First $SampleRows)) {
            $record = [ordered]@{}
            foreach ($header in $headers) {
                $record[$header] = ConvertTo-JevCellValue $row.$header
            }
            [pscustomobject] $record
        }
    )

    $state = [pscustomobject]@{
        WorksheetName = $sheetName
        Headers       = $headers
        SampleRows    = $sample
    }

    $invokeParams = @{
        State    = $state
        Question = $question
    }
    if ($Mock) { $invokeParams.Mock = $true }
    $decision = Invoke-Jev @invokeParams

    $answer = if ($decision.answers -is [System.Collections.IDictionary]) {
        $decision.answers['subject']
    }
    else {
        $decision.answers.subject
    }
    if ($null -eq $answer) {
        throw "Jev returned no subject answer for $sheetName."
    }

    $choice = ([string] $answer.choice).Trim()
    $canonical = @($criteria.Keys | Where-Object { $_ -eq $choice } | Select-Object -First 1)
    if (-not $canonical) {
        throw "Jev returned '$choice' for $sheetName, which is not one of the supplied labels: $($criteria.Keys -join ', ')."
    }

    $confidence = [double] $answer.confidence
    $outputLabel = if ($canonical -eq 'Unknown' -or $confidence -lt $ConfidenceThreshold) {
        Get-UniqueSheetLabel -Label "Review-$sheetName" -Used $usedNames
    }
    else {
        Get-UniqueSheetLabel -Label $canonical -Used $usedNames
    }

    $workbookPath = Join-Path $outputPath "$outputLabel.xlsx"
    $package = $rows | Select-Object -Property $headers | Export-Excel -Path $workbookPath -WorksheetName $outputLabel -AutoSize -BoldTopRow -FreezeTopRow -PassThru
    try {
        Set-SheetNumberFormats -Worksheet $package.Workbook.Worksheets[$outputLabel] -Headers $headers
    }
    finally {
        Close-ExcelPackage -ExcelPackage $package
    }

    [pscustomobject]@{
        SourceSheet = $sheetName
        Columns     = $headers.Count
        SampledRows = $sample.Count
        JevLabel    = $canonical
        Confidence  = [math]::Round($confidence, 2)
        OutputName  = $outputLabel
        Rows        = $rows.Count
    }
}

Write-Host "Wrote $(@($summary).Count) workbooks to $outputPath" -ForegroundColor Cyan
$summary | Format-Table SourceSheet, Columns, SampledRows, JevLabel, Confidence, OutputName, Rows -AutoSize
