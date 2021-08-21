function Test-PackageInstalled {
    [CmdletBinding()]
    param (
        # Name of the package to check if installed
        [Parameter(Mandatory, Position=0)]
        [ValidateScript({$_ -notmatch '\s'})]
        [string[]]
        $Package
    )

    $verSBlock = {param($str=$resp)[regex]::Match($str,'([\d\.]+)').Groups[1].Value}

    foreach ($app in $Package) {

        switch -Regex ($app) {

            # First handle any special cases

            '^brew$|^homebrew$'  {

                $resp = (brew config) -like 'HOMEBREW_VERSION*' | Where-Object {$_}
                [PSCustomObject]@{
                    Package   = 'homebrew'
                    Installed = ( -not [string]::IsNullOrWhiteSpace($resp) )
                    Version = [version](Invoke-Command $verSBlock -arg $resp)
                    #[version]($resp -replace '^HOMEBREW_VERSION:\s')
                }
 
            }

            '^apt$|^apt-get$'    {

                $resp = (apt --version)

                [PSCustomObject]@{
                    Package   = 'apt'
                    Installed = ( -not [string]::IsNullOrWhiteSpace($resp) )
                    Version = [version](Invoke-Command $verSBlock -arg $resp)
                    #[version]($resp -replace '^HOMEBREW_VERSION:\s')
                    # [version](
                    #     $resp verSBlock -replace '^apt\s' -replace '\s[\s\(\)\w\d]$'
                    # )
                }
                
            }

            '^yum$'    {

                $resp = (yum --version)[0]

                [PSCustomObject]@{
                    Package   = 'yum'
                    Installed = ( -not [string]::IsNullOrWhiteSpace($resp) )
                    Version = [version]$resp
                }

            }
 
            # Then everything that is a 1:1 string

            Default {

                if ($IsMacOS) {

                    $hasBrew = Test-PackageInstalled -Package 'brew' |
                        Sort-Object -Property Version -Descending |
                        Select-Object -First 1

                    $resp = if ($hasBrew.Installed) {
                        brew list ( $app.ToLower() )
                    } else {
                        throw "Homebrew package manager is not installed!"
                    }

                    [PSCustomObject]@{
                        Package   = $app.ToLower()
                        Installed = ( -not [string]::IsNullOrWhiteSpace($resp) )
                        Version = [version](Invoke-Command $verSBlock -arg $resp)
                    }

                } elseif ($IsLinux) {

                    $aptORyum = Test-PackageInstalled -Package 'apt','yum' |
                        Where-Object {$_.Installed} |
                        Sort-Object -Property Version -Descending |
                        Select-Object -ExpandProperty 'Package' -First 1

                    $resp = if ($aptORyum -eq 'apt') {
                        dpkg -l ($app.ToLower()) | grep ($app.ToLower())
                    } elseif ($aptORyum -eq 'yum') {
                        ( yum list ($app.ToLower()) )[-1]
                    } else {
                        throw "Unhandled package manager: $($app)"
                    }

                    [PSCustomObject]@{
                        Package   = $app.ToLower()
                        Installed = ( [string]::IsNullOrWhiteSpace($resp) )
                        Version = [version](Invoke-Command $verSBlock -arg $resp)
                    }
                    
                } else {
                    Write-Error "Unhandled OS: $(uname)" -ea 'Continue'
                }

            }#END: Default {}

        }#END: switch -Regex ($app) {}
    
    }#END: foreach ($app in $Test) {}

}#END: function Test-PreRequisite {}
