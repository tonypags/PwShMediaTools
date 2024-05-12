#!/usr/bin/pwsh

<#
.SYNOPSIS
Converts high bitrate videos of any type to smaller x264 MP4. Confirms mp4 file before sending original file to the trash.
#>
param([int]$crf=24)

ipmo PwshMediaTools -ea Stop

# Specify the working folders
$base_folder  = "/garage/media/TV"
$trash_folder  = '/garage/transients/trash'
$chmod_recurse = "/garage/media/recurse_chmod_media.sh" # post-script to normalize owner/mode
$maxItems = 10 # how many TV shows to show the enduser at once
$minSize = 3.8GB # how big does a file have to be to get converted

# Find top directories by size
$i = 0
$allFolders = Get-ChildItem $base_folder -Directory
Write-Host 'inspecting show sizes..' -NoNewLine
$sizedFolders = foreach ($show in $allFolders) {
    $i++
    $kids = Get-ChildItem $show.FullName -File -Recurse | Where-Object Length -gt $minSize
    $size = $kids | Measure-Object -Property Length -Sum | % Sum
    [PsCustomObject]@{
        '#' = $i
        Show = $show.Name
        SizeGB = [math]::Round(($size/1GB),0) -as [int]
        Files = @($kids).Count
        FullName = $show.FullName
    }
    Write-Host '.' -NoNewLine
    Start-Sleep -milli 10
}
Write-Host 'DONE!' -f Green

$bigFolders = $sizedFolders | Sort-Object SizeGB -Desc | Select-Object -First $maxItems
if ($null -eq $bigFolders) {Write-Host 'No Files found :(' -f Red; return}

do {
    Write-Host "`nChoose a TV Show to Compress/Trash"
    Write-Host ($bigFolders | Ft -a | out-string)
    [int]$entry = Read-Host "Choose any of these (enter #, Enter/0 to abort)"
    $choice = $bigFolders | ? '#' -eq $entry
    $yn = Read-Host "Compress $($choice.Files) episodes of $($choice.Show) (y/N)?"

} while ($yn -notmatch 'y*')

Push-Location

$kids = Get-ChildItem $choice.FullName -File -Recurse | Where-Object Length -gt $minSize
Write-Host ($kids | Ft -a | out-string)
$yn = Read-Host "Are you sure you want to compress these files @CRF $crf and trash them (y/N)?"
if ($yn -notlike 'y*') {return}

# for each item, convert it, confirm it, touch old item, move it to trash
$i = 0
$totalGbSaved = 0
foreach ($item in $kids) {
    $i++

    Write-Host "Converting Episode" -NoNewLine ; Write-Host " [$($i) of $($choice.Files)]: $($item.Name)`n" -f Green
    cd "$($item.Directory)"

    # convert it
    $newName = "$($item.Basename).mp4"
    $cmd = "ffmpeg -i `"$($item.Name -replace '"','`"')`" -v quiet -stats -crf $crf `"$($newName -replace '"','`"')`""
    Write-Host "Running this: $cmd `n"
    Invoke-Expression $cmd

    # confirm it
    $oldMeta = Get-MediaInfo "$($item.Name)" | % General
    $newMeta = Get-MediaInfo "$($newName)" -ea 0 | % General

    $bitDiff = $oldMeta.'Overall bit rate (kbps)' - $newMeta.'Overall bit rate (kbps)'
    $bitPct = $bitDiff / $oldMeta.'Overall bit rate (kbps)' * 100 -as [int]
    Write-Host "Bitrate lowered" -NoNewLine ; Write-Host " $($bitPct)% from $($oldMeta.'Overall bit rate (kbps)')k to $($newMeta.'Overall bit rate (kbps)')k" -f Yellow

    $sizeDiff = $oldMeta.'File size' - $newMeta.'File size'
    $sizeDiffGB = [math]::Round(($sizeDiff/1GB),2)
    $totalGbSaved += $sizeDiffGB
    $sizePct = $sizeDiff / $oldMeta.'File size' * 100 -as [int]
    Write-Host "File size lowered" -NoNewLine ; Write-Host " $($sizePct)% or $($sizeDiffGB)GB" -f Yellow

    $durDiff = $oldMeta.Duration.TotalSeconds - $newMeta.Duration.TotalSeconds
    $durDiffSeconds = [math]::Abs($durDiff)
    if ($null -eq $newMeta) {
        Write-Host "Conversion Failed! $($item.Name)" -f Red

    } elseif ($durDiffSeconds -le 1) {

        # touch and trash it
        touch "$($item.Name -replace '"','`"')"
        mv "$($item.Name -replace '"','`"')" "$trash_folder"
        Write-Host "Trashed file:" -NoNewLine ; Write-Host " $($item.Name)" -f Yellow

    } else {

        Write-Host "Duration mismatch! $($item.Name)" -f Red
    }
}
Write-Host "Total space saved: " -NoNewLine ; Write-Host "$($totalGbSaved)GB" -f Green

Pop-Location

Write-Host ""
Write-Host "please run this command now:"
Write-Host ""
Write-Host "sudo $chmod_recurse"
Write-Host ""
Write-Host ""
