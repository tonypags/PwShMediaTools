function Escape-Path {
    param($Path)
    $Path = $Path.Replace('[','``[').Replace(']','``]')
    $Path = $Path.Replace('(','``(').Replace(')','``)')
    $Path = $Path.Replace('"','`"')
    $Path
}
