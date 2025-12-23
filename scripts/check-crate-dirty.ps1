#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Checks if a crate has uncommitted changes since its latest tag.

.DESCRIPTION
    This script determines if a crate is "dirty" by checking if there are any
    changes between the latest tag for that crate and the current HEAD.
    
    It can check a specific crate by name or path, or check all defined crates.

.PARAMETER CrateName
    The name of the crate to check (e.g., "libobs", "libobs-simple").
    If not specified, checks all known crates.

.PARAMETER Path
    Instead of a crate name, provide the path to a crate directory.

.PARAMETER Verbose
    Show detailed information about the comparison.

.EXAMPLE
    ./scripts/check-crate-dirty.ps1 -CrateName libobs
    
.EXAMPLE
    ./scripts/check-crate-dirty.ps1 -Path ./libobs-simple -Verbose
    
.EXAMPLE
    ./scripts/check-crate-dirty.ps1 -Verbose
#>

param(
    [string]$CrateName = "",
    [string]$Path = "",
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

# Define the crates to track
$CRATES = @(
    @{ Name = "libobs"; Path = "libobs" },
    @{ Name = "libobs-simple"; Path = "libobs-simple" },
    @{ Name = "libobs-wrapper"; Path = "libobs-wrapper" },
    @{ Name = "libobs-bootstrapper"; Path = "libobs-bootstrapper" },
    @{ Name = "libobs-window-helper"; Path = "libobs-window-helper" },
    @{ Name = "libobs-simple-macro"; Path = "libobs-simple-macro" },
    @{ Name = "cargo-obs-build"; Path = "cargo-obs-build" }
)

function Get-LatestTagForCrate {
    param([string]$CrateName, [string]$CratePath)
    
    # Look for tags matching the pattern: <crate-name>-v<version>
    $tagPattern = "$CrateName-v*"
    
    $allTags = git tag -l $tagPattern 2>$null | Sort-Object -Descending
    
    if ($LASTEXITCODE -ne 0 -or $allTags.Count -eq 0) {
        return $null
    }
    
    # Return the first (latest) tag
    if ($allTags -is [array]) {
        return $allTags[0]
    } else {
        return $allTags
    }
}

function Test-CrateDirty {
    param(
        [string]$CrateName,
        [string]$CratePath
    )
    
    if (-not (Test-Path $CratePath)) {
        Write-Error "Crate path not found: $CratePath"
        return $null
    }
    
    $latestTag = Get-LatestTagForCrate -CrateName $CrateName -CratePath $CratePath
    
    if (-not $latestTag) {
        if ($Verbose) {
            Write-Host "  No tags found for crate: $CrateName" -ForegroundColor Yellow
        }
        return $null
    }
    
    if ($Verbose) {
        Write-Host "  Latest tag: $latestTag" -ForegroundColor Cyan
    }
    
    # Get the diff between the tag and HEAD for this specific crate path
    $diffOutput = git diff --name-only "$latestTag..HEAD" -- "$CratePath" 2>$null
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to compare tag $latestTag with HEAD"
        return $null
    }
    
    $isDirty = $diffOutput.Count -gt 0
    
    if ($Verbose -and $isDirty) {
        Write-Host "  Changed files:" -ForegroundColor Yellow
        foreach ($file in $diffOutput) {
            Write-Host "    - $file" -ForegroundColor Gray
        }
    }
    
    return $isDirty
}

# Main script execution
Write-Host "=== Crate Dirty Check ===" -ForegroundColor Cyan
Write-Host ""

# Check if we're in a git repository
git rev-parse --git-dir 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Not in a git repository!"
    exit 1
}

# Verify we're in the libobs-rs workspace
if (-not (Test-Path "Cargo.toml" -PathType Leaf)) {
    Write-Error "Not in the libobs-rs workspace root! Cargo.toml not found in current directory."
    Write-Host "Please run this script from the workspace root directory." -ForegroundColor Yellow
    exit 1
}

Write-Host "Workspace: $(Get-Location)" -ForegroundColor Gray
Write-Host ""

# Determine which crates to check
$cratesToCheck = @()

if ($CrateName) {
    # Find crate by name
    $crate = $CRATES | Where-Object { $_.Name -eq $CrateName }
    if (-not $crate) {
        Write-Error "Unknown crate: $CrateName"
        Write-Host "Known crates: $($CRATES | ForEach-Object { $_.Name } | Join-String -Separator ', ')"
        exit 1
    }
    $cratesToCheck = @($crate)
} elseif ($Path) {
    # Use provided path
    $normalizedPath = $Path.TrimEnd('/', '\')
    $crate = $CRATES | Where-Object { $_.Path -eq $normalizedPath }
    if (-not $crate) {
        Write-Host "Path not in known crates list. Checking as custom path: $Path" -ForegroundColor Yellow
        $crateName = Split-Path -Leaf $normalizedPath
        $cratesToCheck = @(@{ Name = $crateName; Path = $normalizedPath })
    } else {
        $cratesToCheck = @($crate)
    }
} else {
    # Check all crates
    $cratesToCheck = $CRATES
}

# Check each crate
$noTagsCrates = @()
$cleanCrates = @()
$dirtyCrates = @()

foreach ($crate in $cratesToCheck) {
    $isDirty = Test-CrateDirty -CrateName $crate.Name -CratePath $crate.Path
    
    if ($null -eq $isDirty) {
        $noTagsCrates += $crate.Name
    } elseif ($isDirty) {
        $dirtyCrates += $crate.Name
    } else {
        $cleanCrates += $crate.Name
    }
}

# Output results
if ($noTagsCrates.Count -gt 0) {
    Write-Host "No Tags:" -ForegroundColor Yellow
    foreach ($crate in $noTagsCrates) {
        Write-Host "- $crate"
    }
    Write-Host ""
}

if ($cleanCrates.Count -gt 0) {
    Write-Host "Clean:" -ForegroundColor Green
    foreach ($crate in $cleanCrates) {
        Write-Host "- $crate"
    }
    Write-Host ""
}

if ($dirtyCrates.Count -gt 0) {
    Write-Host "Dirty:" -ForegroundColor Red
    foreach ($crate in $dirtyCrates) {
        Write-Host "- $crate"
    }
    Write-Host ""
}

# Exit with appropriate code
if ($dirtyCrates.Count -gt 0) {
    exit 1
} else {
    exit 0
}
