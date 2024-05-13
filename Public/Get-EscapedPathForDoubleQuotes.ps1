function Get-EscapedPathForDoubleQuotes {
    <#
    .NOTES
    Always assume the string results will be wrapped in double-quotes
    #>
    [CmdletBinding()]
    [Alias('Escape-Path')]
    param(
        # String with special chars
        [Parameter(Mandatory,Position=0)]
        [string]
        $Path,

        # Expected wrapping
        [Parameter(Position=1)]
        [ValidateNotNull()]
        [ValidateSet('Single','Double')]
        [string]
        $QuoteType = 'Double',

        # Replace any curly quotes with regular quotes (for rename, new name)
        [switch]$New,

        # known issue with get-*item cmdlets
        [switch]$PS7Item
    )

    $esc = if ($PS7Item.IsPresent) { '``' } else { '`' }

    switch ($QuoteType) {
        'Single' {
            $esc =  '``' # why?
            $Path = $Path.Replace("'","''")
            if ($New.IsPresent) {
                $Path = $Path.Replace("’","`'")
                $Path = Use-StraightQuotes -String $Path
            }
        }
        'Double' {
            if ($New.IsPresent) {
                $Path = Use-StraightQuotes -String $Path
            } else {
                $Path = $Path.Replace('“','`“')
                $Path = $Path.Replace('”','`”')
            }
            $Path = $Path.Replace('"','`"')
        }
        Default {Write-Error "Unhandled QuoteType: $($QuoteType)"}
    }

    # This known issue is for () & [] only, I think
    $Path = $Path.Replace('[',"$esc[")
    $Path = $Path.Replace(']',"$esc]")
    $Path = $Path.Replace('(',"$esc(")
    $Path = $Path.Replace(')',"$esc)")

    $Path
}


### WTF why are all the workarounds no longer needed?
# I think I just need it in the top of the mail script
# I also need to ensure double-quotes only are used for this function
# more testing since these changes :( 
