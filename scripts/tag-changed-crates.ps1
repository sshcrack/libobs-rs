#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Automatically tags the current local commit with release tags for changed crates.

.DESCRIPTION
    This script identifies which crates have changed in the current local commit(s)
    and creates git tags for them based on their version in Cargo.toml.
    
    Tags are created in the format: <crate-name>-v<version>
    For example: libobs-v4.0.2, libobs-simple-v6.0.0

.PARAMETER DryRun
    If specified, shows what tags would be created without actually creating them.

.PARAMETER Force
    If specified, overwrites existing tags with the same name.

.PARAMETER Commit
    If specified, tags the given commit hash instead of HEAD. The script will compare
    this commit against its parent (or remote branch) to determine changed crates.

.EXAMPLE
    ./scripts/tag-changed-crates.ps1
    
.EXAMPLE
    ./scripts/tag-changed-crates.ps1 -DryRun
    
.EXAMPLE
    ./scripts/tag-changed-crates.ps1 -Force
    
.EXAMPLE
    ./scripts/tag-changed-crates.ps1 -Commit abc123def
#>

param(
    [switch]$DryRun,
    [switch]$Force,
    [string]$Commit = ""
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

function Get-CargoVersion {
    param([string]$CratePath)
    
    $cargoToml = Join-Path $CratePath "Cargo.toml"
    if (-not (Test-Path $cargoToml)) {
        Write-Warning "Cargo.toml not found at: $cargoToml"
        return $null
    }
    
    $content = Get-Content $cargoToml -Raw
    if ($content -match 'version\s*=\s*"([^"]+)"') {
        $version = $matches[1]
        # Extract base version if it has a + suffix (like "4.0.2+32.0.2")
        if ($version -match '^([^+]+)') {
            return $matches[1]
        }
        return $version
    }
    
    Write-Warning "Could not find version in: $cargoToml"
    return $null
}

function Get-RemoteBranch {
    $currentBranch = git rev-parse --abbrev-ref HEAD 2>$null
    if ($LASTEXITCODE -ne 0) {
        return $null
    }
    
    $remoteBranch = git rev-parse --abbrev-ref "@{u}" 2>$null
    if ($LASTEXITCODE -ne 0) {
        # No upstream branch set, try origin/main or origin/master
        $remote = git remote 2>$null | Select-Object -First 1
        if ($remote) {
            foreach ($branch in @("main", "master")) {
                git rev-parse "refs/remotes/$remote/$branch" 2>$null | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    return "$remote/$branch"
                }
            }
        }
        return $null
    }
    
    return $remoteBranch
}

function Get-ChangedCrates {
    param([string]$TargetCommit = "HEAD")
    
    # Get the remote branch
    $remoteBranch = Get-RemoteBranch
    
    if ($remoteBranch) {
        Write-Host "Comparing against remote branch: $remoteBranch" -ForegroundColor Cyan
        $comparison = "$remoteBranch..$TargetCommit"
    } else {
        Write-Host "No remote branch found, comparing $TargetCommit with ${TargetCommit}~1" -ForegroundColor Yellow
        $comparison = "${TargetCommit}~1..$TargetCommit"
    }
    
    # Get list of changed files
    $changedFiles = git diff --name-only $comparison 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to get changed files. Make sure you have commits in your repository."
        return @()
    }
    
    $changedCrates = @()
    
    foreach ($crate in $CRATES) {
        $cratePrefix = "$($crate.Path)/"
        $hasChanges = $changedFiles | Where-Object { $_.StartsWith($cratePrefix) }
        
        if ($hasChanges) {
            $version = Get-CargoVersion $crate.Path
            if ($version) {
                $changedCrates += @{
                    Name = $crate.Name
                    Path = $crate.Path
                    Version = $version
                    TagName = "$($crate.Name)-v$version"
                }
                Write-Host "  ✓ $($crate.Name) (v$version) has changes" -ForegroundColor Green
            }
        }
    }
    
    return $changedCrates
}

function New-GitTag {
    param(
        [string]$TagName,
        [string]$CrateName,
        [string]$Version,
        [string]$TargetCommit = "HEAD",
        [switch]$DryRun,
        [switch]$Force
    )
    
    # Check if tag already exists
    $tagExists = git tag -l $TagName
    
    if ($tagExists -and -not $Force) {
        Write-Warning "Tag '$TagName' already exists. Use -Force to overwrite."
        return $false
    }
    
    $message = "Release $CrateName v$Version"
    
    if ($DryRun) {
        Write-Host "  [DRY RUN] Would create tag: $TagName at $TargetCommit" -ForegroundColor Magenta
        return $true
    }
    
    $forceFlag = if ($Force) { "-f" } else { "" }
    
    if ($forceFlag) {
        git tag $forceFlag -a $TagName -m $message $TargetCommit
    } else {
        git tag -a $TagName -m $message $TargetCommit
    }
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ Created tag: $TagName at $TargetCommit" -ForegroundColor Green
        return $true
    } else {
        Write-Error "Failed to create tag: $TagName"
        return $false
    }
}

# Main script execution
Write-Host "=== Git Tag Creator for Changed Crates ===" -ForegroundColor Cyan
Write-Host ""

# Check if we're in a git repository
git rev-parse --git-dir 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Not in a git repository!"
    exit 1
}

# Determine target commit
$targetCommit = if ($Commit) {
    # Verify the commit exists
    $resolvedCommit = git rev-parse --verify "$Commit^{commit}" 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Invalid commit hash: $Commit"
        exit 1
    }
    $resolvedCommit
} else {
    git rev-parse HEAD
}

Write-Host "Target commit: $targetCommit" -ForegroundColor Cyan
if ($Commit) {
    $commitInfo = git log -1 --oneline $targetCommit
    Write-Host "  $commitInfo" -ForegroundColor Gray
}
Write-Host ""

# Find changed crates
Write-Host "Analyzing changed crates..." -ForegroundColor Cyan
$changedCrates = Get-ChangedCrates -TargetCommit $targetCommit

if ($changedCrates.Count -eq 0) {
    Write-Host ""
    Write-Host "No crate changes detected in local commits." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Found $($changedCrates.Count) changed crate(s):" -ForegroundColor Cyan
foreach ($crate in $changedCrates) {
    Write-Host "  - $($crate.Name) v$($crate.Version) → $($crate.TagName)" -ForegroundColor White
}
Write-Host ""

# Create tags
if ($DryRun) {
    Write-Host "DRY RUN MODE - No tags will be created" -ForegroundColor Magenta
    Write-Host ""
}

$successCount = 0
foreach ($crate in $changedCrates) {
    $success = New-GitTag -TagName $crate.TagName -CrateName $crate.Name -Version $crate.Version -TargetCommit $targetCommit -DryRun:$DryRun -Force:$Force
    if ($success) {
        $successCount++
    }
}

Write-Host ""
if ($DryRun) {
    Write-Host "Summary: Would have created $successCount tag(s)" -ForegroundColor Cyan
} else {
    Write-Host "Summary: Successfully created $successCount tag(s)" -ForegroundColor Green
    if ($successCount -gt 0) {
        Write-Host ""
        Write-Host "To push tags to remote, run:" -ForegroundColor Cyan
        Write-Host "  git push origin --tags" -ForegroundColor White
    }
}
