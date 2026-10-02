# One question defines the possible answers. PowerShell owns the routing policy.
$questionParams = @{
    Name         = 'category'
    Type         = 'Choice'
    
    Instructions = 'Identify the problem the customer actually needs help with, not just words they mention. Choose unclear when the message does not establish a primary issue.'
    
    Criteria     = @{
        billing        = 'A charge, payment, or invoice is wrong.'
        account_access = 'The customer cannot sign in or access their account.'
        bug            = 'A product feature fails or behaves incorrectly.'
        unclear        = 'The message is too vague or presents several possible issues without identifying the actual problem.'
    }
}

$question = New-JevQuestion @questionParams

$tickets = @(
    [pscustomobject]@{
        Message = "The invoice is fine; I can't log in."
        Id      = 'TICKET-1'
    }
    [pscustomobject]@{
        Message = 'I can log in; the invoice is wrong.'
        Id      = 'TICKET-2'
    }
    [pscustomobject]@{
        Message = 'The export button gives an error every time I click it.'
        Id      = 'TICKET-3'
    }
    [pscustomobject]@{
        Message = 'Something broke again. Maybe billing? Or login? I am not sure.'
        Id      = 'TICKET-4'
    }
)

$results = foreach ($ticket in $tickets) {
    $decision = Invoke-Jev -State $ticket.Message -Question $question

    $route = switch ($decision.category) {
        'billing' { 'Billing queue' }
        'account_access' { 'Account access queue' }
        'bug' { 'Product support queue' }
        'unclear' { 'Human triage: ask for details' }         
        
        default { 'Human triage: unexpected category' }
    }
    
    [pscustomobject]@{
        Ticket   = $ticket.Id
        Message  = $ticket.Message
        Category = $decision.category
        Route    = $route
    }
}

$results 

