#!/usr/bin/pwsh

<#
.SYNOPSIS
Converts high bitrate videos of any type to smaller x264 MP4. Confirms mp4 file before sending original file to the trash.
.NOTES
Tracking good CRFs to use for 750MB results
4.5GB - 28
4.0GB - 27
3.5GB - 27

Try a bash script using this one-liner:
find ./ -name "*.mkv" -exec sh -c 'ffmpeg -i "$1" -crf 27 "$(basename "$1" mkv).mp4"' _ {} \;
find ./ -name "*.flac" -exec sh -c 'ffmpeg -i "$1" "$(basename "$1" flac).m4a"' _ {} \;
#>
param(
    # higher CRF = smaller file
    [int]$crf = 27,

    # how big does a file have to be to get converted
    [int64]$minSize = 4.0GB,

    # how many TV shows to show the enduser at once
    $maxItems = 15
)

ipmo PwshMediaTools -ea Stop -wa 0

# Specify the working folders
$log_folder    = '~/log/top-tv-folders'
$base_folder   = "/garage/media/TV"
$trash_folder  = '/garage/transients/trash'
$chmod_recurse = "/garage/media/recurse_chmod_media.sh" # post-script to normalize owner/mode

# LOGGING
$dt = {(Get-Date).ToString('yyyyMMddTHHmmss.fff')}
$msg = "Starting script..."
echo "[INFO] [$(icm $dt)] $msg" >> $log_folder
$msg = "CRF: $($crf)"
Write-Host $msg
echo "[INFO] [$(icm $dt)] $msg" >> $log_folder
$msg = "minSize: $($minSize) ($($minSize/1GB)GB)"
Write-Host $msg
echo "[INFO] [$(icm $dt)] $msg" >> $log_folder
$msg = "maxItems: $($maxItems)"
Write-Host $msg
echo "[INFO] [$(icm $dt)] $msg" >> $log_folder

# Find top directories by size
$i = 0
$allFolders = Get-ChildItem $base_folder -Directory
Write-Host 'inspecting show sizes..' -NoNewLine
$sizedFolders = foreach ($show in $allFolders) {
    $i++
    $lrgEpisodes = Get-ChildItem $show.FullName -File -Recurse | Where-Object Length -gt $minSize
    # Wait-Debugger;return # temp debug
    if ($null -eq $lrgEpisodes) {continue}
    $size = $lrgEpisodes | Measure-Object -Property Length -Sum | % Sum
    [PsCustomObject]@{
        '#' = $i
        Show = $show.Name
        SizeGB = [math]::Round(($size/1GB),0) -as [int]
        Files = @($lrgEpisodes).Count
        FullName = $show.FullName
    }
    Write-Host '.' -NoNewLine
    Start-Sleep -milli 10
}
Write-Host ' DONE!' -f Green

$bigFolders = $sizedFolders | Sort-Object SizeGB -Desc | Select-Object -First $maxItems
if ($null -eq $bigFolders) {Write-Host 'No Files found :(' -f Red; return}

do {
    Write-Host "`nChoose a TV Show to Compress/Trash"
    Write-Host ($bigFolders | Ft -a | out-string)
    [int]$entry = Read-Host "Choose any of these (enter #, Enter/0 to abort)"
    if ($entry) {} else {return}
    $choice = $bigFolders | ? '#' -eq $entry
    $yn = Read-Host "Compress $($choice.Files) episodes of $($choice.Show) (y/N)?"

} while ($yn -notmatch 'y.*')

$lrgEpisodes = Get-ChildItem ($choice.FullName) -Recurse | Where-Object Length -gt $minSize
Write-Host ($lrgEpisodes | Ft -a | out-string)
# Wait-Debugger
$yn = Read-Host "Are you sure you want to compress these files @CRF $crf and trash them (y/N)?"
if ($yn -notlike 'y*') {return}

Push-Location

# for each item, convert it, confirm it, touch old item, move it to trash
$i = 0
$totalGbSaved = 0
foreach ($item in $lrgEpisodes) {
    $i++
    $showLabel = Split-Path (Split-Path $item.FullName -Parent) -Leaf
    if ($showLabel -like 'Season*') {
        $season = $showLabel
        $showLabel = Split-Path (Split-Path (Split-Path $item.FullName -Parent) -Parent) -Leaf
    } else {
        $season = ''
    }
    $thisLabel = "$showLabel / $season / $($item.Basename)"

    Write-Host "Converting Episode " -NoNewLine ; Write-Host "[$($i) of $($choice.Files)]: $($item.Name)`n" -f Green
    # $this_wdir = Escape-Path -Path $item.Directory
    $this_wdir = $item.Directory
    echo "[INFO] [$(icm $dt)] $thisLabel" >> $log_folder
    cd "$this_wdir"

    # convert it
    $oldName = "$(Escape-Path -Path $item.Name)"
    # $oldName7 = "$(Escape-Path -Path $item.Name -PS7Item)"
    $newName = "$(Use-StraightQuotes -String $item.Basename).mp4"
    $newNameEsc = "$(Escape-Path $newName)"
    # $newName7 = "$(Escape-Path $newName -PS7Item)"
    $cmd = "ffmpeg -i `"$oldName`" -v quiet -stats -crf $crf `"$($newNameEsc)`""
    echo "[INFO] [$(icm $dt)] $cmd" >> $log_folder
    # Wait-Debugger;Pop-Location;return # temp debug
    Invoke-Expression $cmd

    $oldMeta = Get-MediaInfo "$($item.Name)" | % General
    $newMeta = Get-MediaInfo "$($newName)" | % General
    $newItem = Get-Item "$($newName)"
    # Wait-Debugger

    $bitDiff = $oldMeta.'Overall bit rate (bps)' - $newMeta.'Overall bit rate (bps)'
    $bitPct = if ($oldMeta.'Overall bit rate (bps)' -gt 0) {
        $bitDiff / $oldMeta.'Overall bit rate (bps)' * 100 -as [int]
    } else {'??'}
    Write-Host "Bitrate lowered" -NoNewLine ; Write-Host " $($bitPct)% from $($oldMeta.'Overall bit rate (bps)'/1kb)k to $($newMeta.'Overall bit rate (bps)'/1kb)k" -f Yellow

    $sizeDiff = $item.length - $newItem.Length
    $sizeDiffGB = [math]::Round(($sizeDiff/1GB),2)
    $totalGbSaved += $sizeDiffGB
    $sizePct = $sizeDiff / $item.Length * 100 -as [int]
    Write-Host "File size lowered" -NoNewLine ; Write-Host " $($sizePct)% or $($sizeDiffGB)GB" -f Yellow

    # confirm it
    $durDiff = $oldMeta.Duration.TotalSeconds - $newMeta.Duration.TotalSeconds
    $durDiffSeconds = [math]::Abs($durDiff)
    if ($null -eq $newMeta) {
        
        $msg = "Conversion Failed! $($thisLabel)"
        Write-Host $msg -f Red
        echo "[ERROR] [$(icm $dt)] $msg" >> $log_folder

    } elseif ($durDiffSeconds -le 1) {

        # touch and trash it
        touch "$($item.Name)"
        mv "$($item.Name)" "$trash_folder"
        Write-Host "Trashed file:" -NoNewLine ; Write-Host " $($item.Name)" -f Yellow

    } else {

        $msg = "Duration mismatch! $thisLabel"
        Write-Host $msg -f Red
        echo "[ERROR] [$(icm $dt)] $msg" >> $log_folder
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
