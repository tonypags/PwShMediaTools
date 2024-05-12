function Escape-Path {
    <#
    .NOTES
    Always assume the string results is given and will be wrapped in double-quotes
    #>
    param($Path,[switch]$New)
    $Path = $Path.Replace('[','``[').Replace(']','``]')
    $Path = $Path.Replace('(','``(').Replace(')','``)')
    $Path = $Path.Replace('"','`"')
    if ($New.IsPresent) {
        $Path = $Path.Replace('“','`"')
        $Path = $Path.Replace('”','`"')
        $Path = $Path.Replace("’","'")
    } else {
        $Path = $Path.Replace('“','`“')
        $Path = $Path.Replace('”','`”')
        $Path = $Path.Replace("’","'’")
    }
    $Path
}
