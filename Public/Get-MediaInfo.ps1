function Get-MediaInfo {
    <#
    .SYNOPSIS
    Gets media file info.
    .DESCRIPTION
    Gets media file info, including bitrate and duration.
    .EXAMPLE
    Get-Item ./Awesome-Movie.mp4 | Get-MediaInfo
    .INPUTS
    File objects or strings
    .OUTPUTS
    A PSCustomObject representing parsed output from the mediainfo utility
    #>
    [CmdletBinding()]
    param (
        [Parameter(
            Position=0,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        [ValidateScript({
            (Test-Path $_) -or
            -not [string]::IsNullOrWhiteSpace((ls "$_"))
        })]
        [string[]]
        $Path,

        [switch]$Bitrate

    )
    
    begin {
        
        $prereq = Test-PackageInstalled 'mediainfo'
        if ($prereq.Installed) {} else {
            throw 'mediainfo not installed!'
        }

        $SectionHeaders = @{}
        $thisSection = ''

        $strDateProps = @{
            Delimiter = ':'
            ErrorAction = 'Stop'
            StringData = $null
        }

    }
    
    process {
        
        foreach ($file in $Path) {

            $rawResponse = (mediainfo $file | Out-String) -split "`n"

            foreach ($line in $rawResponse) {

                # Ignore lines without content
                if ([string]::IsNullOrWhiteSpace($line)) {} else {

                    Try {

                        # Convert the key:value string to a hash entry
                        $strDateProps.StringData = $line
                        $rawKeyValue = ConvertFrom-StringData @strDateProps
                        $key = @($rawKeyValue.keys)[0]
                        $rawValue = $rawKeyValue[$key].Trim()
                    
                        # Detect data types
                        switch -Regex ($rawValue) {
                            '[\d\.]+\smb\/s' { # Bitrates Mbps
                                [int64]$value = ($rawValue -replace 'mb.*$' -as [double]) * 1MB
                                $key = "$Key (bps)"
                                break
                            }
                            '[\d\.]+\skb\/s' { # Bitrates Kbps
                                [int64]$value = ($rawValue -replace 'kb.*$' -as [double]) * 1kB
                                $key = "$Key (bps)"
                                break
                            }
                            '\d+\smi?n?\s\d+\sse?c?s?|\d+\sho?u?r?s?\s\d+\smi?n?s?' { # Timespans

                                $hrs  = [regex]::Match($rawValue,'(\d+?)\s+?h').Groups[1].Value
                                $mins = [regex]::Match($rawValue,'(\d+?)\s+?m').Groups[1].Value
                                $secs = [regex]::Match($rawValue,'(\d+?)\s+?s').Groups[1].Value
                                $props = @{}
                                if ($hrs) {$props.Hours = [int]$hrs}
                                if ($mins) {$props.Minutes = [int]$mins}
                                if ($secs) {$props.Seconds = [int]$secs}
                                $value = New-Timespan @props
                                $key = "$Key"
                                break
                            }
                            '\d+\spixels' { # Size/px
                                $value = ($rawValue -replace '[^\d]') -as [int]
                                $key = "$Key"
                                break
                            }
                            '\d+\sbit' { # Bit depth
                                $value = ($rawValue -replace '[^\d]') -as [int]                                
                                $key = "$Key"
                                break
                            }
                            '^\d+\.\d+$' { # Doubles
                                $value = [double]$rawValue
                                $key = "$Key"
                                break
                            }
                            '^\d+\.\d+\sFPS.*$' { # Frame Rates (Doubles)
                                $value = [double]($rawValue -replace '\sFPS$')
                                $key = "$Key (FPS)"
                                break
                            }
                            '^\d+\sMiB$' { # Size convert MiB to MB to B (Doubles)
                                $value = [int]($rawValue -replace '\sMiB$')*
                                [math]::Pow(2,20)/[math]::Pow(10,6)*1MB
                                $key = "$Key"
                                break
                            }
                            '^\d+$' { # Integers
                                $value = [int]$rawValue
                                $key = "$Key"
                                break
                            }
                            '^\d+\schannels?$' { # channels (Integers)
                                $value = [int]($rawValue -replace '\schannels?$')
                                $key = "$Key"
                                break
                            }
                            '^UTC\s\d{4}' { # UTC Dates
                                $value = ($rawValue -replace 'UTC\s' -as [datetime]).ToLocalTime().ToUniversalTime()
                                $key = "$Key (UTC)"
                                break
                            }
                            Default { $value = $rawValue }
                        }#END: switch

                        # Add to Section hash variable
                        $thisHash.$key = $value

                    } Catch {

                        # Section headers do not have a Key:Value string and will throw
                        if ($_ -like "*is not in 'name=value' format.*") {

                            # First commit/nest an existing hash
                            if ($thisSection) { # Runs every time except the first time thru loop
                                $SectionHeaders.Add($thisSection, [pscustomobject]$thisHash)
                            }

                            # Then (re-)initialize variables for a new section
                            $thisSection = $line.Trim() # Hash key is Header
                            $thisHash = [ordered]@{} # Empty Nested hash for the next loop

                        }

                    }

                }#END: Ignore lines without content

            }#END: foreach ($line in $rawResponse) {}

            # $SectionHeaders.Add($thisSection, [pscustomobject]$thisHash)
                        
        }#END: foreach ($file in $Path) {}

        if ($Bitrate.IsPresent) {

            ([pscustomobject]$SectionHeaders.General.'Overall bit Rate' -replace '[^\d]') -as [int]

        } else {

            [pscustomobject]$SectionHeaders

        }

    }#END: process {}
    
    end {
    
    }

}#END: function Get-MediaInfo {}

<# SAMPLE DATA

see file lib/Get-MediaInfo.sample.data

#>
