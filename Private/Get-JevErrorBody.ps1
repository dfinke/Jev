function Get-JevErrorBody {
    <# Attempts to preserve the API's useful error payload when available. #>
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
