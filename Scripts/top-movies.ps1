#!/usr/bin/pwsh

<#
.SYNOPSIS
Converts high bitrate videos of any type to smaller x264 MP4. Confirms mp4 file before sending original file to the trash.
.NOTES
Tracking good CRFs to use for 750MB results
4.5GB - 28
4.0GB - 27
3.5GB - 27

Tracking good CRFs to use for 1GB results
4.0GB - 26???

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
    $maxItems = 25
)

ipmo PwshMediaTools -Force -ea Stop -wa 0

# Specify the working folders
$log_folder    = '~/log/top-movies'
$base_folder   = "/garage/media/Movies"
$trash_folder  = '/garage/transients/trash'
$chmod_recurse = "/garage/media/recurse_chmod_movies.sh" # post-script to normalize owner/mode
$null = if (Test-Path $log_folder) {} else {New-Item $log_folder -Force}

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

$i = 1
# Find top directories by size
$exts = Get-MovieFileExtensions | ForEach-Object {"*.$($_)"}
$allMovieFiles = Get-ChildItem $base_folder -Recurse -File -Include $exts | Where-Object {$_.Length -ge $minSize} | Sort-Object Length -Desc | Select-Object -First $maxItems
Write-Host 'inspecting movie sizes..' -NoNewLine
$ptnIgnoredKeywords = 'Despecialized'
$biggestMovies = foreach ($movie in $allMovieFiles) {
    if ($movie.Name -match $ptnIgnoredKeywords) {continue}
    [PsCustomObject]@{
        '#' = $i
        Movie = $movie.Name
        SizeGB = [math]::Round(($Movie.Length/1GB),0) -as [int]
        FullName = $movie.FullName
    }
    $i++
}

if ($null -eq $biggestMovies) {Write-Host 'No Files found :(' -f Red; return}

$arrEntry = @()
do {
    Write-Host "`nChoose a Movie(s) to Compress/Trash"
    Write-Host ($biggestMovies | Format-Table -a | out-string)
    [string]$entry = Read-Host "Choose any of these (enter # ... 0 to abort)`n"
    if ($entry -eq '0') {return} elseif ($entry) {} else {continue}
    $arrEntry += $entry.Trim()
    $chosenMovies = $biggestMovies | Where-Object '#' -in $arrEntry
    $MovieCount = ($chosenMovies|Measure-Object).Count
    $yn = Read-Host "Add another movie file to the queue of $($MovieCount) movies?:`n    $($chosenMovies.Movie -join "`n    ")`n`n(Y/n)?"
    
} while ($yn -notmatch 'n.*')

Write-Host ($chosenMovies | Format-Table -a | out-string)
$yn = Read-Host "Are you sure you want to compress these files @CRF $crf and trash them (y/N)?"
if ($yn -notlike 'y*') {return}

Push-Location

# for each item, convert it, confirm it, touch old item, move it to trash
$i = 0
$totalGbSaved = 0
foreach ($item in $chosenMovies) {
    $i++
    $this_wdir = Split-Path $item.FullName -Parent
    $this_file = Split-Path $item.FullName -Leaf
    $this_base = $this_file -replace '\.\w{2,9}$'

    $thisLabel = $item.Movie
    cd "$($this_wdir)" -ea Stop
    Write-Host "Converting Movie " -NoNewLine ; Write-Host "[$($i) of $($MovieCount)]: $($thisLabel)`n" -f Green
    echo "[INFO] [$(icm $dt)] $thisLabel" >> $log_folder

    # convert it
    $oldName = "$(Get-EscapedPathForDoubleQuotes -Path $this_file)"
    $newName = "$(Use-StraightQuotes -String $this_base).mp4"
    $newNameEsc = "$(Get-EscapedPathForDoubleQuotes $newName)"
    $cmd = "ffmpeg -i `"$oldName`" -v quiet -stats -crf $crf `"$($newNameEsc)`""
    echo "[INFO] [$(icm $dt)] $cmd" >> $log_folder
    Invoke-Expression $cmd
    Sleep -milli 10

    $oldMeta = Get-MediaInfo "$($item.Name)" | % General
    $newMeta = Get-MediaInfo "$($newName)" | % General
    $newItem = Get-Item "$($newName)"

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
