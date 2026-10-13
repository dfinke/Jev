Clear-Host
# Classify a tool request, then apply local policy to produce a preview only.

$requests = (Get-Content (Join-Path $PSScriptRoot 'guarded-request.json') -Raw | ConvertFrom-Json).requests

$intentQuestion = New-JevQuestion -Name intent -Type Choice `
    -Instructions 'What kind of operation is requested?' `
    -Criteria @{
        read    = 'Inspect status or retrieve information without changing a resource.'
        restart = 'Restart or recover an existing service.'
        delete  = 'Delete data or permanently remove a resource.'
        unclear = 'The requested operation or target is unclear.'
    }

$requests | Invoke-Jev -Question $intentQuestion | ForEach-Object {
    $request = $_

    # Jev interprets each request; this switch applies the same local policy to every result.
    $outcome = switch ($request.intent) {
        read {
            'Preview: read-only inspection can proceed.'
        }
        restart {
            if ($request.environment -eq 'Production' -and -not $request.approvalRecorded) {
                'Approval required before a production restart.'
            }
            else {
                'Preview: restart is eligible for the next guarded step.'
            }
        }
        delete {
            'Denied: destructive requests require a separate approved workflow.'
        }
        default {
            'Manual review: the request is unclear or outside this example policy.'
        }
    }

    [pscustomobject]@{
        Request       = $request.request
        Requester     = $request.requester
        Service       = $request.service
        Intent        = $request.intent
        Environment   = $request.environment
        PolicyOutcome = $outcome
    }
}
