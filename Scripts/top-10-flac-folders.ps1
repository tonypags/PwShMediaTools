#!/usr/bin/pwsh

<#
.SYNOPSIS
Converts FLAC albums to Mpeg4 Audio. Confirms m4a file before sending flac to the trash.
#>

ipmo PwshMediaTools -ea Stop

# Specify the working folders
$music_folder  = "/garage/media/Music"
$trash_folder  = '/garage/transients/trash'
$chmod_recurse = "$music_folder/recurse_chmod_Music.sh" # post-script to normalize owner/mode

# Find all directories containing *.flac files
$flacFiles = Get-ChildItem $music_folder -Include '*.flac' -Recurse
$dirGroup = $flacFiles | Group-Object Directory -NoElement

# Tally up the file sizes in each folder
$i = 0
$FolderSizes = [System.Collections.ArrayList]@()
foreach ($parent in $dirGroup.Name) {
    
    $i++
    $theseSongs = Get-ChildItem "$parent/*.flac"
    $thisMeasure = $theseSongs | Measure-Object -Property Length -Sum
    $thisSize = $thisMeasure | % Sum
    [void] $FolderSizes.Add(
        [PsCustomObject]@{
            '#' = $i
            Size = "$([math]::Round(($thisSize / 1MB)))M"
            Album = (Split-Path $parent -Leaf)
            Path = $parent
            Bytes = $thisSize
        }
    )
    Start-Sleep -milli 100
}

# wait-debugger
# return

# Display the top 10 items and ask to exclude any
$topTen = $FolderSizes|? bytes -gt 0 |sort-object bytes -desc | select-object -first 10
if ($null -eq $topTen) {Write-Host 'No Flac Files found :)' -f Green; return}

do {
    clear-Host
    Write-Host "`nConverting these FLAC files to M4A files? (then touch & move FLACs to $trash_folder/)"
    $topTen | sort-object '#' | Ft -a
    [int]$choice = Read-Host "Exclude any of these? (enter # to exclude, Enter/0 to continue)"
    $topTen = $topTen | ? '#' -ne $choice

} while ($choice -ne 0)

clear-Host
$topTen | sort-object '#' | Ft -a
$yn = Read-Host 'Are you sure you want to convert these files and trash them (y/N)?'
if ($yn -notlike '*y*') {return}

Push-Location

# Execute loop on all album folders
$totalAlbums = @($topTen).Count
$iAlbum = 0
foreach ($item in $topTen) {
    $iAlbum++

    cd "$($item.Path)"
    Write-Host "$('=' * $host.UI.RawUI.WindowSize.Width)`n
    `nConverting Album" -NoNewLine ; Write-Host " [$($iAlbum) of $($totalAlbums)]: $($item.Album)`n" -f Green

    # for each item, convert it, confirm it, touch old item, move it to trash
    $flacs = Get-ChildItem "*.flac"
    $totalSongs = @($flacs).Count
    $iSong = 0
    foreach ($song in $flacs) {
        $iSong++

        # convert it
        $newName = "$($song.Basename).m4a"
        $cmd = "ffmpeg -i `"$($song.Name -replace '"','`"')`" -v quiet -stats -vsync 0 `"$($newName -replace '"','`"')`""
        Write-Host "`nConverting Song " -NoNewLine ; Write-Host " [$($iSong) of $($totalSongs)]: $($song.Name)" -f Cyan
        Write-Host "Running this: $cmd `n"
        Invoke-Expression $cmd

        # confirm it
        $oldMeta = Get-MediaInfo "$($song.Name)" | % General
        $newMeta = Get-MediaInfo "$($newName)" | % General
        $durDiff = $oldMeta.Duration.TotalSeconds - $newMeta.Duration.TotalSeconds
        $durDiffSeconds = [math]::Abs($durDiff)

        if ($durDiffSeconds -le 1) {

            # touch and trash it
            touch "$($song.Name -replace '"','`"')"
            mv "$($song.Name -replace '"','`"')" "$trash_folder"
            Write-Host "Trashed file:" -NoNewLine ; Write-Host " $($song.Name)" -f Yellow

        } else {

            Write-Host "Duration mismatch! $($item.Album) / $($song.Name)" -f Red
        }
        # break # temp debug
    }
    # break # temp debug
}

Pop-Location

Write-Host ""
Write-Host "please run this command now:"
Write-Host ""
Write-Host "sudo $chmod_recurse"
Write-Host ""
Write-Host ""
