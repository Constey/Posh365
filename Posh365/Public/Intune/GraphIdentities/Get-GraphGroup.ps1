function Get-GraphGroup {
    [CmdletBinding()]
    param (
        [Parameter()]
        $GroupId,

        [Parameter(ParameterSetName = 'Name')]
        $Name
    )

    if ([datetime]::UtcNow -ge $TimeToRefresh) { Connect-PoshGraphRefresh }
    switch ($PSCmdlet.ParameterSetName) {
        'Name' {
            $RestSplat = @{
                Uri     = "https://graph.microsoft.com/beta/groups/?`$filter=displayName eq '$Name'"
                Headers = @{ "Authorization" = "Bearer $Token" }
                Method  = 'Get'
            }
        }
        default {
            $RestSplat = @{
                Uri     = 'https://graph.microsoft.com/beta/groups/{0}' -f $GroupId
                Headers = @{ "Authorization" = "Bearer $Token" }
                Method  = 'Get'
            }
        }

    }
    Invoke-RestMethod @RestSplat -Verbose:$false

}
