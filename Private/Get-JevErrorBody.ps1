<#
.SYNOPSIS
    Extracts the API error body when the exception provides one.

.PARAMETER Exception
    The exception raised by the failed HTTP request.
#>
function Get-JevErrorBody {
    param([Parameter(Mandatory)] [System.Exception] $Exception)

    try {
        if ($null -ne $Exception.Response) {
            $stream = $Exception.Response.GetResponseStream()
            if ($null -ne $stream) {
                $reader = [System.IO.StreamReader]::new($stream)
                return $reader.ReadToEnd()
            }
        }
    }
    catch {
        # Keep the original exception as the primary error.
    }

    return $Exception.Message
}
