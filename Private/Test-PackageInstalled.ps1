function Test-PackageInstalled {
    [CmdletBinding()]
    param (
        # Name of the package to check if installed
        [Parameter(Mandatory, Position=0)]
        [string[]]
        $Package
    )

    foreach ($app in $Package) {

        switch -Regex ($app) {

            # First handle any special cases

            '^brew$|^homebrew$'  {

                [PSCustomObject]@{
                    Package   = 'homebrew'
                    Installed = [bool]((brew config) -like 'HOMEBREW_VERSION*')
                    Version = [version](
                        ((brew config) -like 'HOMEBREW_VERSION*') -replace '^HOMEBREW_VERSION:\s'
                    )

                }
 
            }

            '^apt$|^apt-get$'    {

                $resp = (apt --version)

                [PSCustomObject]@{
                    Package   = 'apt'
                    Installed = (-not [string]::IsNullOrWhiteSpace($resp))
                    Version = [version](
                        $resp -replace '^apt\s' -replace '/s\(.+\)$'
                    )
                }
                
            }

            '^yum$'    {

                $resp = (yum --version)[0]

                [PSCustomObject]@{
                    Package   = 'yum'
                    Installed = (-not [string]::IsNullOrWhiteSpace($resp))
                    Version = [version]$resp
                }

            }
 
            # Then everything that is a 1:1 string

            Default {

                if ($IsMacOS) {
                    [PSCustomObject]@{
                        Package   = $app.ToLower()
                        Installed = ((brew list) -contains ($app.ToLower()))
                        Version = [version]([regex]::Match(
                            (  brew list ( $app.ToLower() )  ), '([\d\.]+)'
                        ).Groups[1].Value)
                    }
                } elseif ($IsLinux) {

                    $aptORyum = Test-PackageInstalled -Package 'apt','yum' |
                        Where-Object {$_.Installed} |
                        Select-Object -ExpandProperty 'Package'

                    $resp = if ($aptORyum -eq 'apt') {

                    } elseif ($aptORyum -eq 'yum') {

                    } else {
                        throw "Unhandled package manager: $($app)"
                    }
                    
                    [PSCustomObject]@{
                        Package   = $app.ToLower()
                        Installed = (
                            [string]::IsNullOrWhiteSpace(
                                ((apt list | grep ^ffmpeg) -match ($app.ToLower()))
                            )
                        )
                        Version = [version](
                            (apt --version) -replace '^apt\s' -replace '/s\(.+\)$'
                        )
                    }
                    
                } else {
                    Write-Error "Unhandled OS: $(uname)" -ea 'Continue'
                }

            }#END: Default {}

        }#END: switch -Regex ($app) {}
    
    }#END: foreach ($app in $Test) {}

}#END: function Test-PreRequisite {}
