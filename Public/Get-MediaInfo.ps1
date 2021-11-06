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
        [ValidateScript({Test-Path $_})]
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

    }
    
    process {
        
        foreach ($file in $Path) {

            $rawResponse = (mediainfo $file | Out-String) -split "`n"

            foreach ($line in $rawResponse) {

                # Ignore lines without content
                if ([string]::IsNullOrWhiteSpace($line)) {} else {

                    Try {
                        
                        # Convert the key:value string to a hash entry
                        $strDateProps = @{
                            Delimiter = ':'
                            ErrorAction = 'Stop'
                            StringData = $line
                        }
                        $rawKeyValue = ConvertFrom-StringData @strDateProps
                        $key = $rawKeyValue.keys
                        $rawValue = $rawKeyValue[$key]

                        $value = @{}
                        # Detect data types
                        $value.$key = switch -Regex ($rawValue) {
                            
                            # Timespans
                            '\d\d?\smin\s\d\d?\ss' {
                                $mins = [regex]::Match($rawValue,'(d\d?)\smin').Groups[1].Value
                                $secs = [regex]::Match($rawValue,'(\d\d?)\ss').Groups[1].Value
                                $props = @{
                                    Minutes = [int]$mins
                                    Seconds = [int]$secs
                                }
                                New-Timespan $props
                                break
                            }

                            # Bitrates
                            '\d+\sk?m?b\/s' {
                                ($rawValue -replace '[^\d]') -as [int]
                                break
                            }

                            # Size/px
                            '\d+\spixels' {
                                ($rawValue -replace '[^\d]') -as [int]
                                break
                            }

                            # Bit depth
                            '\d+\sbit' {
                                ($rawValue -replace '[^\d]') -as [int]                                
                                break
                            }

                            # Doubles
                            '^\d+\.\d+$' {
                                [double]$rawValue
                                break
                            }

                            # Integers
                            '^\d+$' {
                                [int]$rawValue
                                break
                            }

                            Default { $rawValue }

                        }#END: switch

                        # Add to Section hash variable
                        $thisHash = $value + $thisHash

                    } Catch {

                        # Section headers do not have a Key:Value string and will throw
                        if ($_ -like "*is not in 'name=value' format.*") {

                            # First commit/nest an existing hash
                            if ($thisSection) {
                                $SectionHeaders.Add($thisSection, [pscustomobject]$thisHash)
                            }

                            # Then (re-)initialize variables for a new section
                            $thisSection = $line.Trim() # Hash key is Header
                            $thisHash = @{} # Empty Nested hash for the next loop

                        }

                    }

                }#END: Ignore lines without content

            }#END: foreach ($line in $rawResponse) {}

            $SectionHeaders.Add($thisSection, [pscustomobject]$thisHash)
            
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
