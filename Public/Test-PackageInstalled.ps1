function Test-PackageInstalled {
    [CmdletBinding()]
    param (
        # Name of the package to check if installed
        [Parameter(Mandatory, Position=0)]
        [ValidateScript({$_ -notmatch '\s'})]
        [string[]]
        $Package
    )

    $ptn = '([\d\.]+)'
    $verSBlock = { param($str) [regex]::Match($str,$ptn).Groups[1].Value }

    foreach ($app in $Package) {

        switch -Regex ($app) {

            # First handle any special cases

            '^brew$|^homebrew$'  {

                $resp = (brew config) -like 'HOMEBREW_VERSION*' | Where-Object {$_}
                $installed = -not [string]::IsNullOrWhiteSpace($resp)

                $props = @{
                    Package   = 'homebrew'
                    Installed = ( -not [string]::IsNullOrWhiteSpace($resp) )
                    #[version]($resp -replace '^HOMEBREW_VERSION:\s')
                }
                if ($installed) {$props.Add('Version',(
                    [version](Invoke-Command $verSBlock -arg $resp)
                ))}
                [PSCustomObject]$props
            
            }

            '^apt$|^apt-get$'    {

                $resp = (apt --version)
                $installed = -not [string]::IsNullOrWhiteSpace($resp)

                $props = @{
                    Package   = 'apt'
                    Installed = $installed
                    #[version]($resp -replace '^HOMEBREW_VERSION:\s')
                    # [version](
                    #     $resp verSBlock -replace '^apt\s' -replace '\s[\s\(\)\w\d]$'
                    # )
                }
                if ($installed) {$props.Add('Version',(
                    [version](Invoke-Command $verSBlock -arg $resp)
                ))}
                [PSCustomObject]$props
                
            }

            '^yum$'    {

                $resp = (yum --version)[0]
                $installed = -not [string]::IsNullOrWhiteSpace($resp)

                $props = @{
                    Package   = 'yum'
                    Installed = $installed
                    # Version = [version]$resp
                }
                if ($installed) {$props.Add('Version',(
                    [version](Invoke-Command $verSBlock -arg $resp)
                ))}
                [PSCustomObject]$props

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
                    $installed = -not [string]::IsNullOrWhiteSpace($resp)

                    $props = @{
                        Package   = $app.ToLower()
                        Installed = $installed
                    }
                    if ($installed) {$props.Add('Version',(
                        [version](Invoke-Command $verSBlock -arg $resp)
                    ))}
                    [PSCustomObject]$props

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
                    $installed = -not [string]::IsNullOrWhiteSpace($resp)

                    $props = @{
                        Package   = $app.ToLower()
                        Installed = $installed
                        #[version]($resp -replace '^HOMEBREW_VERSION:\s')
                        # [version](
                        #     $resp verSBlock -replace '^apt\s' -replace '\s[\s\(\)\w\d]$'
                        # )
                    }
                    if ($installed) {$props.Add('Version',(
                        [version](Invoke-Command $verSBlock -arg $resp)
                    ))}
                    [PSCustomObject]$props
                    
                } else {
                    Write-Error "Unhandled OS: $(uname)" -ea 'Continue'
                }

            }#END: Default {}

        }#END: switch -Regex ($app) {}
    
    }#END: foreach ($app in $Test) {}

}#END: function Test-PreRequisite {}
