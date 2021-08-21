function Test-PackageInstalled {
    [CmdletBinding()]
    param (
        # Name of the package to check if installed
        [Parameter(Mandatory, Position=0)]
        [string[]]
        $Test
    )

    foreach ($t in $Test) {

        if ($IsMacOS) {
            [PSCustomObject]@{
                Package   = $t.ToLower()
                Installed = ((brew list) -contains ($t.ToLower()))
            }
        } elseif ($IsLinux) {
            [PSCustomObject]@{
                Package   = $t.ToLower()
                Installed = (
                    [string]::IsNullOrWhiteSpace(
                        ((apt list | grep ^ffmpeg) -match ($t.ToLower()))
                    )
                )
            }
            
        } else {
            throw "Unhandled OS: "
        }
    
    }

}#END: function Test-PreRequisite {}
