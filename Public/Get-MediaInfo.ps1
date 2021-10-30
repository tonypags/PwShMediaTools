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
        [System.IO.FileInfo[]]
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


General
Complete name                            : ./Californication.S03E12.Mia.Culpa.mkv
Format                                   : Matroska
Format version                           : Version 2
File size                                : 1.09 GiB
Duration                                 : 28 min 46 s
Overall bit rate                         : 5 421 kb/s
Writing application                      : mkvmerge v4.1.1 ('Bouncin' Back') built on Jul  3 2010 22:54:08
Writing library                          : libebml v1.0.0 + libmatroska v1.0

Video
ID                                       : 1
Format                                   : AVC
Format/Info                              : Advanced Video Codec
Format profile                           : High@L4.1
Format settings                          : CABAC / 5 Ref Frames
Format settings, CABAC                   : Yes
Format settings, ReFrames                : 5 frames
Codec ID                                 : V_MPEG4/ISO/AVC
Duration                                 : 28 min 46 s
Bit rate                                 : 4 779 kb/s
Width                                    : 1 280 pixels
Height                                   : 720 pixels
Display aspect ratio                     : 16:9
Frame rate mode                          : Constant
Frame rate                               : 23.976 (24000/1001) FPS
Color space                              : YUV
Chroma subsampling                       : 4:2:0
Bit depth                                : 8 bits
Scan type                                : Progressive
Bits/(Pixel*Frame)                       : 0.216
Stream size                              : 962 MiB (86%)
Writing library                          : x264 core 135 r2345 f0c1c53
Encoding settings                        : cabac=1 / ref=5 / deblock=1:-2:-2 / analyse=0x3:0x113 / me=umh / subme=8 / psy=1 / psy_rd=1.00:0.00 / mixed_ref=1 / me_range=16 / chroma_me=1 / trellis=1 / 8x8dct=1 / cqm=0 / deadzone=21,11 / fast_pskip=1 / chroma_qp_offset=-2 / threads=12 / lookahead_threads=2 / sliced_threads=0 / nr=0 / decimate=1 / interlaced=0 / bluray_compat=0 / constrained_intra=0 / bframes=3 / b_pyramid=2 / b_adapt=2 / b_bias=0 / direct=3 / weightb=1 / open_gop=0 / weightp=2 / keyint=240 / keyint_min=24 / scenecut=40 / intra_refresh=0 / rc_lookahead=50 / rc=2pass / mbtree=1 / bitrate=4779 / ratetol=1.0 / qcomp=0.60 / qpmin=0 / qpmax=69 / qpstep=4 / cplxblur=20.0 / qblur=0.5 / ip_ratio=1.40 / aq=1:1.00
Language                                 : English
Default                                  : Yes
Forced                                   : No

Audio
ID                                       : 2
Format                                   : AC-3
Format/Info                              : Audio Coding 3
Codec ID                                 : A_AC3
Duration                                 : 28 min 46 s
Bit rate mode                            : Constant
Bit rate                                 : 640 kb/s
Channel(s)                               : 6 channels
Channel positions                        : Front: L C R, Side: L R, LFE
Sampling rate                            : 48.0 kHz
Frame rate                               : 31.250 FPS (1536 SPF)
Bit depth                                : 16 bits
Compression mode                         : Lossy
Stream size                              : 132 MiB (12%)
Language                                 : English
Service kind                             : Complete Main
Default                                  : Yes
Forced                                   : No

Text #1
ID                                       : 3
Format                                   : UTF-8
Codec ID                                 : S_TEXT/UTF8
Codec ID/Info                            : UTF-8 Plain Text
Language                                 : English
Default                                  : No
Forced                                   : No

Text #2
ID                                       : 4
Format                                   : UTF-8
Codec ID                                 : S_TEXT/UTF8
Codec ID/Info                            : UTF-8 Plain Text
Title                                    : SDH
Language                                 : English
Default                                  : No
Forced                                   : No

Menu
00:00:00.000                             : en:00:00:00.000
00:01:17.035                             : en:00:01:17.035
00:11:36.696                             : en:00:11:36.696
00:21:35.127                             : en:00:21:35.127
00:28:09.313                             : en:00:28:09.313



#>
