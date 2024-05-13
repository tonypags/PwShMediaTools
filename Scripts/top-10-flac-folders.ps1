#!/usr/bin/pwsh

<#
.SYNOPSIS
Converts FLAC albums to Mpeg4 Audio. Confirms m4a file before sending flac to the trash.
#>

ipmo PwshMediaTools -force -ea Stop -wa 0

# Specify the working folders
$log_folder    = '~/log/top-ten-flac-folders'
$music_folder  = "/garage/media/Music"
$trash_folder  = '/garage/transients/trash'
$chmod_recurse = "$music_folder/recurse_chmod_Music.sh" # post-script to normalize owner/mode

# LOGGING
$dt = {(Get-Date).ToString('yyyyMMddTHHmmss.fff')}
$msg = "Starting script..."
echo "[INFO] [$(icm $dt)] $msg" >> $log_folder

# Find all directories containing *.flac files
$flacFiles = Get-ChildItem $music_folder -Include '*.flac' -Recurse
$dirGroup = $flacFiles | Group-Object Directory -NoElement

# Tally up the file sizes in each folder
$i = 0
$FolderSizes = [System.Collections.ArrayList]@()
$albumsToRename = [System.Collections.ArrayList]@()
Write-Host 'inspecting album sizes..' -NoNewLine
foreach ($album in $dirGroup) {

    $i++
    $theseSongs = Get-ChildItem "$(Escape-Path -Path $album.Name -PS7Item)" -Recurse | ? Extension -eq '.flac'
    $thisMeasure = $theseSongs | Measure-Object -Property Length -Sum
    $thisSize = $thisMeasure | % Sum
    [void] $FolderSizes.Add(
        [PsCustomObject]@{
            '#' = $i
            Size = "$([math]::Round(($thisSize / 1MB)))M"
            Album = (Split-Path $album.Name -Leaf)
            Path = $album.Name
            Bytes = $thisSize
        }
    )
    # break # temp debug
    Write-Host '.' -NoNewLine
    Start-Sleep -milli 100
}
Write-Host ' DONE!' -f Green

if ($albumsToRename) {
    Write-Host -f Red "Albums to rename:`n$(
        ($albumsToRename.Name | % {$_ -replace '^\/garage\/media\/Music\/'}) -join "`n"
    )"
}

# Display the top 10 items and ask to exclude any
$topTen = $FolderSizes|? bytes -gt 0 |sort-object bytes -desc | select-object -first 10
if ($null -eq $topTen) {Write-Host 'No Flac Files found :)' -f Green -b DarkYellow; return}

do {
    Write-Host "`nConverting these FLAC files to M4A files? (then touch & move FLACs to $trash_folder/)"
    $topTen | sort-object '#' | Ft -a
    [int]$choice = Read-Host "Exclude any of these? (enter # to exclude, Enter/0 to continue)"
    $topTen = $topTen | ? '#' -ne $choice

} while ($choice -ne 0)

$topTen | sort-object '#' | Ft -a
$yn = Read-Host 'Are you sure you want to convert these files and trash them (y/N)?'
if ($yn -notlike '*y*') {return}

Push-Location

# Execute loop on all album folders
$totalAlbums = @($topTen).Count
$iAlbum = 0
$totalGbSaved = 0
foreach ($item in $topTen) {
    $iAlbum++
    $artist = Split-Path (Split-Path $item.Path -Parent) -Leaf

    $this_wdir = Escape-Path -Path $item.Path -PS7Item
    echo "[INFO] [$(icm $dt)] cd `"$($this_wdir)`"" >> $log_folder
    Set-Location "$this_wdir"
    Write-Host "$('=' * $host.UI.RawUI.WindowSize.Width)`n
    `nConverting $($artist) Album " -NoNewLine ; Write-Host "[$($iAlbum) of $($totalAlbums)]: $($item.Album)`n" -f Green

    # for each item, convert it, confirm it, touch old item, move it to trash
    $flacs = Get-ChildItem "*.flac"
    $totalSongs = @($flacs).Count
    $iSong = 0
    foreach ($song in $flacs) {
        $iSong++
        $thisLabel = "$($artist) / $($item.Album) / $($song.Name)"

        # convert it
        $oldName = "$(Escape-Path -Path $song.Name)"
        $oldName7 = "$(Escape-Path -Path $song.Name -PS7Item)"
        $newName = "$(Use-StraightQuotes -String $song.Basename).m4a"
        $newNameEsc = "$(Escape-Path $newName)"
        $newName7 = "$(Escape-Path $newName -PS7Item)"
        $cmd = "ffmpeg -i `"$oldName`" -v quiet -stats -vsync 0 -vn `"$($newNameEsc)`""
        Write-Host "`nConverting Song " -NoNewLine ; Write-Host " [$($iSong) of $($totalSongs)]: $($song.Name)" -f Cyan
        echo "[INFO] [$(icm $dt)] $cmd" >> $log_folder
        #Wait-Debugger;Pop-Location;return # temp debug
        Invoke-Expression $cmd

        $oldMeta = Get-MediaInfo $song.Name | % General
        $newMeta = Get-MediaInfo $newName | % General
        $newItem = Get-Item $newName
        # Wait-Debugger

        $sizeDiff = $song.Length - $newItem.Length
        $sizeDiffMB = [math]::Round(($sizeDiff/1MB),0)
        $sizeDiffGB = [math]::Round(($sizeDiff/1GB),2)
        $totalGbSaved += $sizeDiffGB
        $sizePct = ($sizeDiff / $song.Length * 100) -as [int]
        Write-Host "File size lowered" -NoNewLine ; Write-Host " $($sizePct)% or $($sizeDiffMB)MB" -f Yellow

        # confirm it
        $durDiff = $oldMeta.Duration.TotalSeconds - $newMeta.Duration.TotalSeconds
        $durDiffSeconds = [math]::Abs($durDiff)
        if ($null -eq $newMeta) {
            $msg = "Conversion Failed! $($thisLabel)"
            Write-Host $msg -f Red
            echo "[ERROR] [$(icm $dt)] $msg" >> $log_folder

        } elseif ($durDiffSeconds -le 1) {

            # touch and trash it
            touch "$($song.Name)"
            mv "$($song.Name)" "$trash_folder"
            Write-Host "Trashed file:" -NoNewLine ; Write-Host " $($song.Name)" -f Yellow
            # Wait-Debugger

        } else {

            $msg = "Duration mismatch! $thisLabel"
            Write-Host $msg -f Red
            echo "[ERROR] [$(icm $dt)] $msg" >> $log_folder
        }
        # break # temp debug
    }
    # break # temp debug
}
$msg1 = "Total space saved: "
$msg2 = "$($totalGbSaved)GB"
Write-Host -NoNewLine $msg1; Write-Host $msg2 -f Green
echo "[INFO] [$(icm $dt)] $msg1 $msg2" >> $log_folder

Pop-Location

Write-Host ""
Write-Host "Log file available here: $log_folder"
Write-Host ""
Write-Host "please run this command now:"
Write-Host ""
Write-Host "sudo $chmod_recurse"
Write-Host ""
Write-Host ""
