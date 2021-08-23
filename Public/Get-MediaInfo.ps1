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
        $Path
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

                if ([string]::IsNullOrWhiteSpace($line)) {} else {

                    Try {
                        
                        # Capture property or handle various conditions below
                        $strDateProps = @{
                            Delimiter = ':'
                            ErrorAction = 'Stop'
                            StringData = $line
                        }
                        $thisHash = (ConvertFrom-StringData @strDateProps) + $thisHash

                    } Catch {

                        if ($_ -like "*is not in 'name=value' format.*") {

                            # This is a section Header
                            # First commit/nest the existing hash
                            if ($thisSection) {
                                $SectionHeaders.Add($thisSection, [pscustomobject]$thisHash)
                            }

                            # Then start a new section
                            $thisSection = $line.Trim()
                            $thisHash = @{}

                        }

                    }

                }#END: if ([string]::IsNullOrWhiteSpace($line)) {continue} else {}

            }#END: foreach ($line in $rawResponse) {}

            $SectionHeaders.Add($thisSection, [pscustomobject]$thisHash)
            
        }#END: foreach ($file in $Path) {}

        [pscustomobject]$SectionHeaders

    }#END: process {}
    
    end {
    
    }

}#END: function Get-MediaInfo {}
