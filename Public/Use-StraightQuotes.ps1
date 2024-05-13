function Use-StraightQuotes {
    param(
        [Parameter(Position=0)]
        [string]$String
    )
    $String = $String.Replace('“','"')
    $String = $String.Replace('”','"')
    $String = $String.Replace("’","'")
    $String
}
