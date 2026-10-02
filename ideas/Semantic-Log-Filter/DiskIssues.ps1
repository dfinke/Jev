Clear-Host

$logLines = @"
2026-09-27 06:01:12 INFO  Service started on port 8080
2026-09-27 06:02:45 INFO  Nightly disk check passed
2026-09-27 06:03:10 WARN  Volume /var at 98% capacity
2026-09-27 06:04:22 ERROR write failed: ENOSPC
2026-09-27 06:05:01 INFO  User jsmith logged in
2026-09-27 06:05:33 ERROR No space left on device
2026-09-27 06:06:14 WARN  Temp directory quota policy updated
2026-09-27 06:07:48 ERROR Cannot extend tablespace USERS: out of storage
2026-09-27 06:08:02 INFO  Cache cleared, 0 items removed
2026-09-27 06:09:19 WARN  Backup job skipped: target drive full
2026-09-27 06:10:05 ERROR Connection to db01 timed out
2026-09-27 06:11:30 INFO  Disk space report emailed to ops
"@ -split "`n"

$question = New-JevQuestion -Name diskIssue -Type Noul `
    -Instructions 'Does this log entry indicate that a storage volume, filesystem, or database tablespace is full or close to full, causing writes or backups to fail?' `
    -Criteria @{
    true  = 'Storage capacity is exhausted or nearly exhausted and is causing, or is likely to cause, failed writes or backups.'
    false = 'The entry only mentions disks, space, or quotas without indicating a storage capacity problem.'
}

$final = foreach ($entry in $logLines) {
    $result = Invoke-Jev -State $entry -Question $question
    
    $Assessment = if ($result.diskIssue -ge 0.8) { 'Storage issue' }
    elseif ($result.diskIssue -le 0.2) { 'No storage issue' }
    else { 'Review' }

    [pscustomobject][ordered]@{
        State      = $result.State
        Assessment = $Assessment
        DiskIssue  = $result.diskIssue
    }   
} 

$final | Sort-Object DiskIssue -Descending | Format-Table -AutoSize