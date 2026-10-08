BeforeAll {
    . "$PSScriptRoot/New-LoanApplication.ps1"
    . "$PSScriptRoot/Get-LoanDecision.ps1"
    Import-Module Jev -ErrorAction Stop
}

Describe 'Loan application construction' -Tag Local {
    It 'creates a reusable application with numeric fields' {
        $application = New-LoanApplication -Income 80000 -Requested 20000 -CreditScore 710 -Debt 5000
        $application | Should -BeOfType [pscustomobject]
        $application.Income | Should -Be 80000
        $application.Requested | Should -Be 20000
        $application.CreditScore | Should -Be 710
        $application.Debt | Should -Be 5000
        $application.RequestedPercentIncome | Should -Be 25
        $application.DebtPercentIncome | Should -Be 31.25
        $application.CreditScore = 640
        $application.CreditScore | Should -Be 640
    }

    It 'preserves the calculated percentages for <Case>' -TestCases @(
        @{ Case = 'high debt'; Requested = 30000; Debt = 5000; RequestedPercent = 37.5; DebtPercent = 43.75 }
        @{ Case = 'amount just below half'; Requested = 39999; Debt = 0; RequestedPercent = 49.99875; DebtPercent = 49.99875 }
        @{ Case = 'debt exactly at the limit'; Requested = 20000; Debt = 12000; RequestedPercent = 25; DebtPercent = 40 }
        @{ Case = 'debt just above the limit'; Requested = 20000; Debt = 12001; RequestedPercent = 25; DebtPercent = 40.00125 }
    ) {
        param($Case, $Requested, $Debt, $RequestedPercent, $DebtPercent)
        $application = New-LoanApplication -Income 80000 -Requested $Requested -CreditScore 710 -Debt $Debt
        $application.RequestedPercentIncome | Should -Be ([decimal] $RequestedPercent)
        $application.DebtPercentIncome | Should -Be ([decimal] $DebtPercent)
        $application.RequestedPercentIncome | Should -BeOfType [decimal]
        $application.DebtPercentIncome | Should -BeOfType [decimal]
    }

    It 'refreshes percentages before sending a changed application to Jev' {
        Mock Invoke-Jev { @{ answers = @{ outcome = @{ choice = 'Approve' } } } }
        $application = New-LoanApplication -Income 80000 -Requested 20000 -CreditScore 710 -Debt 5000
        $application.Income = 100000
        $application | Get-LoanDecision | Out-Null
        Should -Invoke Invoke-Jev -Exactly 1 -Scope It -ParameterFilter {
            $State.Income -eq 100000 -and $State.RequestedPercentIncome -eq 20 -and $State.DebtPercentIncome -eq 25
        }
    }

    It 'rejects an invalid edited field before calling Jev' {
        Mock Invoke-Jev { throw 'Invalid application reached Jev.' }
        $application = New-LoanApplication -Income 80000 -Requested 20000 -CreditScore 710 -Debt 5000
        $application.Income = 0
        { $application | Get-LoanDecision } | Should -Throw
        Should -Invoke Invoke-Jev -Exactly 0 -Scope It
    }

    It 'rejects an out-of-range <Field> value of <Value>' -TestCases @(
        @{ Field = 'Income'; Value = 0 }
        @{ Field = 'Income'; Value = 10000001 }
        @{ Field = 'Requested'; Value = 0 }
        @{ Field = 'Requested'; Value = 10000001 }
        @{ Field = 'CreditScore'; Value = 299 }
        @{ Field = 'CreditScore'; Value = 9000 }
        @{ Field = 'Debt'; Value = -1 }
        @{ Field = 'Debt'; Value = 10000001 }
    ) {
        param($Field, $Value)
        $parameters = @{ Income = 80000; Requested = 20000; CreditScore = 710; Debt = 5000 }
        $parameters[$Field] = $Value
        { New-LoanApplication @parameters } | Should -Throw
    }
}

Describe 'Loan decisions against the live Jev model' -Tag Live {
    It 'matches the ordered policy: <Case>' -TestCases @(
        @{ Case = 'approval'; Income = 80000; Requested = 20000; CreditScore = 710; Debt = 5000; Decision = 'Approve'; Reason = 'All approval conditions met' }
        @{ Case = 'amount rule before low credit and high DTI'; Income = 80000; Requested = 40000; CreditScore = 640; Debt = 30000; Decision = 'Deny'; Reason = 'Amount over half of income' }
        @{ Case = 'credit rule before high DTI'; Income = 80000; Requested = 20000; CreditScore = 640; Debt = 20000; Decision = 'Refer'; Reason = 'Credit score below 680' }
        @{ Case = 'high DTI'; Income = 80000; Requested = 30000; CreditScore = 710; Debt = 5000; Decision = 'Deny'; Reason = 'DTI over 0.4' }
        @{ Case = 'credit exactly 680'; Income = 80000; Requested = 20000; CreditScore = 680; Debt = 5000; Decision = 'Approve'; Reason = 'All approval conditions met' }
        @{ Case = 'credit just below 680'; Income = 80000; Requested = 20000; CreditScore = 679; Debt = 5000; Decision = 'Refer'; Reason = 'Credit score below 680' }
        @{ Case = 'amount exactly half'; Income = 80000; Requested = 40000; CreditScore = 710; Debt = 0; Decision = 'Deny'; Reason = 'Amount over half of income' }
        @{ Case = 'amount below half but high DTI'; Income = 80000; Requested = 39999; CreditScore = 710; Debt = 0; Decision = 'Deny'; Reason = 'DTI over 0.4' }
        @{ Case = 'DTI exactly 0.4'; Income = 80000; Requested = 20000; CreditScore = 680; Debt = 12000; Decision = 'Approve'; Reason = 'All approval conditions met' }
        @{ Case = 'DTI just over 0.4'; Income = 80000; Requested = 20000; CreditScore = 710; Debt = 12001; Decision = 'Deny'; Reason = 'DTI over 0.4' }
    ) {
        param($Case, $Income, $Requested, $CreditScore, $Debt, $Decision, $Reason)
        $state = New-LoanApplication -Income $Income -Requested $Requested -CreditScore $CreditScore -Debt $Debt
        $result = Get-LoanDecision -State $state

        $result.Decision | Should -Be $Decision
        $result.Reason | Should -Be $Reason
        $result | Should -BeOfType [pscustomobject]
        @($result.PSObject.Properties.Name) | Should -Be @('Decision', 'Reason')
    }

    It 'changes the decision when only the credit score changes' {
        $state = New-LoanApplication -Income 80000 -Requested 20000 -CreditScore 710 -Debt 5000
        ($state | Get-LoanDecision).Decision | Should -Be 'Approve'
        $state.CreditScore = 640
        ($state | Get-LoanDecision).Decision | Should -Be 'Refer'
        $state.Income | Should -Be 80000
        $state.Requested | Should -Be 20000
        $state.Debt | Should -Be 5000
    }

    It 'returns the expected results for five piped states' {
        $states = @(
            New-LoanApplication -Income 80000 -Requested 20000 -CreditScore 710 -Debt 5000
            New-LoanApplication -Income 80000 -Requested 40000 -CreditScore 640 -Debt 30000
            New-LoanApplication -Income 80000 -Requested 20000 -CreditScore 640 -Debt 20000
            New-LoanApplication -Income 80000 -Requested 30000 -CreditScore 710 -Debt 5000
            New-LoanApplication -Income 80000 -Requested 20000 -CreditScore 680 -Debt 12000
        )
        $results = @($states | Get-LoanDecision)
        $results.Count | Should -Be 5
        $results.Decision | Should -Be @('Approve', 'Deny', 'Refer', 'Deny', 'Approve')
    }

    It 'repeats the same baseline decision with the same model and state' {
        $state = New-LoanApplication -Income 80000 -Requested 20000 -CreditScore 710 -Debt 5000
        $first = $state | Get-LoanDecision
        $second = $state | Get-LoanDecision
        $first.Decision | Should -Be 'Approve'
        $second.Decision | Should -Be $first.Decision
        $second.Reason | Should -Be $first.Reason
    }
}
