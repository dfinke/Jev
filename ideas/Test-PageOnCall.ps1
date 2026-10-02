# Build both criteria entries for a Noul yes/no question.
function New-YesNoCriteria {
    [CmdletBinding()]
    param (
        # Describe what a "yes" means.
        [Parameter(Mandatory)]
        [string] $TrueCriteria,

        # Describe what a "no" means.
        [Parameter(Mandatory)]
        [string] $FalseCriteria
    )

    # Return the criteria dictionary Jev expects.
    return @{
        true  = $TrueCriteria
        false = $FalseCriteria
    }
}

# Create a friendly yes/no question using Jev's question format.
function New-YesNo {
    [CmdletBinding()]
    param (
        # Name used for the answer property in Invoke-Jev's output.
        [Parameter(Mandatory)]
        [string] $Name,

        # The human-readable question Jev should answer.
        [Parameter(Mandatory)]
        [string] $Question,

        # The true/false criteria created by New-YesNoCriteria.
        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Criteria
    )

    # Require both sides of the yes/no decision.
    if ('true' -notin $Criteria.Keys -or 'false' -notin $Criteria.Keys) {
        throw 'Criteria must contain both true and false entries.'
    }

    # Map the friendly question to Jev's existing Instructions field.
    New-JevQuestion `
        -Name $Name `
        -Type Noul `
        -Instructions $Question `
        -Criteria $Criteria
}

# Ask Jev whether the on-call engineer should be paged.
function Test-PageOnCall {
    [CmdletBinding()]
    param (
        # The incident, event, or other state Jev should evaluate.
        [Parameter( ValueFromPipeline)]
        $State
    )

    process {
        # Build the yes/no question and its criteria.
        $question = New-YesNo `
            -Name pageOnCall `
            -Question 'Should the on-call engineer be paged now?' `
            -Criteria (New-YesNoCriteria `
                -TrueCriteria 'Customers cannot complete purchases' `
                -FalseCriteria 'Purchases are working normally')

        # Send the state and question to Jev.
        $jevResult = Invoke-Jev -State $State -Question $question

        # Return the state and the Boolean decision.
        [pscustomobject]@{            
            PageOnCall = if ($jevResult.answers.pageOnCall.noul -ge .8) { "Yes" } else { "No" }
            State      = $State
        }
    }
}

# Supply 10 states to evaluate.
$states = @(
    'Checkout is returning HTTP 503 errors, and no customers can place orders.'
    'Checkout is slower than usual, but customers are still completing purchases successfully.'
    'The payment provider is declining every transaction. Customers cannot complete purchases.'
    'The payment provider is degraded, but the backup processor is handling all transactions.'
    'About 30 percent of checkout attempts are failing with a payment timeout.'
    'The internal reporting dashboard is down. Checkout and customer purchases are working normally.'
    'The orders database is unavailable, so checkout cannot save or complete purchases.'
    "A single customer’s payment failed because their card was declined. Other purchases are succeeding."
    'Customers are unable to buy anything after the latest deployment. The failure has lasted 12 minutes.'
    'A scheduled maintenance check is running. No checkout errors or failed purchases have been reported.'
)

# Evaluate each state and display the Boolean decision beside it.
$states |  Test-PageOnCall 