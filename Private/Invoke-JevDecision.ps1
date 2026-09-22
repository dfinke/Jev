#requires -Version 7.0

Set-StrictMode -Version Latest

function Invoke-JevDecision {
    <#
    .SYNOPSIS
        Sends one state value and a named question dictionary to Jev.

    .PARAMETER State
        The string, object, or array all questions should evaluate.

    .PARAMETER Questions
        A hashtable whose values are typed Jev questions.  The wrapper accepts
        either lower-case API types or the readable Noul/Choice/Score spellings.

    .PARAMETER UseMock
        Return a schema-compatible local response without making an HTTP call.

    .PARAMETER MockOnMissingKey
        Use mock mode only when TYPESAFE_API_KEY is missing.  HTTP failures still
        fail loudly so production problems are not hidden.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [AllowNull()]
        [object] $State,

        [Parameter(Mandatory, Position = 1)]
        [System.Collections.IDictionary] $Questions,

        [string] $Model = 'jev-latest',

        [uri] $Endpoint = 'https://api.typesafe.ai/v1/systemone',

        [ValidateRange(1, 300)]
        [int] $TimeoutSec = 30,

        [ValidateRange(0, 5)]
        [int] $MaxRetries = 2,

        [ValidateRange(0, 10000)]
        [int] $RetryDelayMs = 250,

        [switch] $UseMock,

        [switch] $MockOnMissingKey
    )

    process {
        if ($null -eq $State) {
            throw 'State cannot be null.'
        }
        if ($Questions.Count -eq 0) {
            throw 'Questions must contain at least one named question.'
        }

        $normalizedQuestions = [ordered] @{}
        foreach ($questionEntry in $Questions.GetEnumerator()) {
            $questionName = [string] $questionEntry.Key
            if ([string]::IsNullOrWhiteSpace($questionName)) {
                throw 'Every Jev question must have a non-empty name.'
            }
            if ($null -eq $questionEntry.Value) {
                throw "Question '$questionName' cannot be null."
            }

            $question = ConvertTo-JevDictionary -Value $questionEntry.Value
            if (-not $question.Contains('type')) {
                throw "Question '$questionName' is missing its type. Use Noul, Choice, or Score."
            }
            $type = ([string] $question.type).ToLowerInvariant()
            if ($type -notin @('noul', 'choice', 'score')) {
                throw "Question '$questionName' has unsupported type '$($question.type)'. Use Noul, Choice, or Score."
            }

            $normalizedQuestion = @{ type = $type }
            if ($question.Contains('instructions')) {
                $normalizedQuestion['instructions'] = $question['instructions']
            }

            switch ($type) {
                'noul' {
                    if ($question.Contains('criteria')) { $normalizedQuestion['criteria'] = $question['criteria'] }
                }
                'choice' {
                    if (-not $question.Contains('criteria')) { throw "Choice question '$questionName' requires criteria." }
                    $criteria = ConvertTo-JevDictionary -Value $question.criteria
                    if ($criteria.Count -eq 0) { throw "Choice question '$questionName' requires at least one criterion." }
                    $normalizedQuestion['criteria'] = $criteria
                }
                'score' {
                    if (-not $question.Contains('criteria')) { throw "Score question '$questionName' requires criteria." }
                    $criteria = @($question.criteria)
                    if ($criteria.Count -eq 0) { throw "Score question '$questionName' requires at least one level." }
                    $normalizedQuestion['criteria'] = $criteria
                }
            }

            $normalizedQuestions[$questionName] = $normalizedQuestion
        }

        $apiKey = [string] $env:TYPESAFE_API_KEY
        $shouldMock = $UseMock.IsPresent -or ($MockOnMissingKey.IsPresent -and [string]::IsNullOrWhiteSpace($apiKey))

        if ($shouldMock) {
            return Invoke-JevMockDecision -State $State -Questions $normalizedQuestions -Model $Model
        }

        if ([string]::IsNullOrWhiteSpace($apiKey)) {
            throw 'TYPESAFE_API_KEY is not set. Set it or use -UseMock for offline testing.'
        }

        $request = [ordered] @{
            state     = $State
            model     = $Model
            questions = $normalizedQuestions
        }
        $body = $request | ConvertTo-Json -Depth 30 -Compress

        try {
            # The public API currently calls this endpoint /v1/systemone.
            for ($attempt = 0; $attempt -le $MaxRetries; $attempt++) {
                try {
                    return Invoke-RestMethod `
                        -Uri $Endpoint `
                        -Method Post `
                        -Headers @{ Authorization = "Bearer $apiKey" } `
                        -ContentType 'application/json' `
                        -Body $body `
                        -TimeoutSec $TimeoutSec `
                        -ErrorAction Stop
                }
                catch {
                    $statusCode = 0
                    try {
                        if ($null -ne $_.Exception.Response) {
                            $statusCode = [int] $_.Exception.Response.StatusCode.value__
                        }
                    }
                    catch {
                        # Some PowerShell/.NET exception types do not expose a status code.
                    }

                    $retryable = $statusCode -in @(408, 425, 429) -or $statusCode -ge 500
                    $lastAttempt = $attempt -ge $MaxRetries
                    if (-not $retryable -or $lastAttempt) {
                        throw
                    }

                    # Exponential backoff prevents a busy service or rate limit from
                    # turning one pipeline item into a tight retry loop.
                    $delay = [math]::Min(10000, $RetryDelayMs * [math]::Pow(2, $attempt))
                    Start-Sleep -Milliseconds ([int] $delay)
                }
            }
        }
        catch {
            $details = Get-JevErrorBody -Exception $_.Exception
            throw "Jev request failed at '$Endpoint': $details"
        }
    }
}
