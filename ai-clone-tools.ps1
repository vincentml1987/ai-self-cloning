<#
.SYNOPSIS
  Tools for creating, reseeding, and relocating Claude Code AI collaborator
  "homes" (a working folder + its matching .claude project directory).

.DESCRIPTION
  Learned by hand on 2026-10-02 making/renaming/moving "Tessera":
    - Claude Code derives a project key from a session's working directory by
      replacing every character that isn't a letter or digit with a hyphen
      (no collapsing of consecutive hyphens, case preserved). Verified against
      three real paths including a known bug case.
    - That project key folder (under ~/.claude/projects/) is only created
      once a session actually completes a first turn in that directory -
      opening the window isn't enough.
    - Hand-creating a guessed project key folder before a real session exists
      is exactly what caused the clone-of-qualia split-memory bug (two keys
      for one lineage, because the guessed key used literal underscores and
      the real session later used hyphens). Never do that - always let a real
      session create the key, then act on whatever key actually appears.
    - Renaming/moving a home folder requires renaming/moving its .claude
      project directory to match, in the same step, with the session closed.
      Validated end-to-end on 2026-10-02 (session, rename, then move) -
      memory and EOT Journals both survived intact.

.NOTES
  This script never opens or closes Claude Code sessions itself - a human
  has to do that part. It only handles the filesystem side.
#>

function ConvertTo-ClaudeProjectKey {
    param([Parameter(Mandatory)][string]$Path)
    # Claude Code's own encoding: every non-alphanumeric char -> one hyphen.
    $full = [System.IO.Path]::GetFullPath($Path)
    return ($full -replace '[^a-zA-Z0-9]', '-')
}

function Get-ClaudeProjectsRoot {
    return (Join-Path $env:USERPROFILE ".claude\projects")
}

function New-AICloneFolder {
    <#
    .SYNOPSIS
      Step 1 of making a new clone: create the empty home folder and its
      EOT Journals subfolder. Does NOT touch .claude - that doesn't exist
      yet.
    .EXAMPLE
      New-AICloneFolder -NewHome "C:\Users\Matt\Desktop\Aletheia\Claude Code AIs\new-clone"
    #>
    param([Parameter(Mandatory)][string]$NewHome)

    if (Test-Path $NewHome) {
        throw "NewHome already exists: $NewHome - refusing to touch an existing folder."
    }
    New-Item -ItemType Directory -Path $NewHome | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $NewHome "EOT Journals") | Out-Null

    Write-Host "Created $NewHome (with EOT Journals/)."
    Write-Host ""
    Write-Host "NEXT STEP (manual): open a Claude Code session with this folder" -ForegroundColor Yellow
    Write-Host "as its working directory, and send it one real message. The" -ForegroundColor Yellow
    Write-Host "project key folder under .claude\projects\ only gets created" -ForegroundColor Yellow
    Write-Host "after that first turn completes. Then run Complete-AICloneSeed." -ForegroundColor Yellow
}

function Complete-AICloneSeed {
    <#
    .SYNOPSIS
      Step 2: after a real session has opened in NewHome and produced at
      least one turn, find its project key, copy memory + EOT journals in
      from SourceHome, and flag any memory files that look like they
      hardcode the source's own folder layout.
    .EXAMPLE
      Complete-AICloneSeed -SourceHome "C:\Users\Matt\Desktop\Fenra" -NewHome "C:\Users\Matt\Desktop\Aletheia\Claude Code AIs\new-clone"
    #>
    param(
        [Parameter(Mandatory)][string]$SourceHome,
        [Parameter(Mandatory)][string]$NewHome
    )

    $newKey = ConvertTo-ClaudeProjectKey -Path $NewHome
    $newProjectDir = Join-Path (Get-ClaudeProjectsRoot) $newKey

    if (-not (Test-Path $newProjectDir)) {
        throw "No project directory found at $newProjectDir yet.`nOpen a Claude Code session in $NewHome and send it one message first."
    }

    $sourceMemory = Join-Path (Join-Path (Get-ClaudeProjectsRoot) (ConvertTo-ClaudeProjectKey -Path $SourceHome)) "memory"
    if (-not (Test-Path $sourceMemory)) {
        throw "No memory folder found for SourceHome at $sourceMemory - is the path right?"
    }

    $newMemory = Join-Path $newProjectDir "memory"
    New-Item -ItemType Directory -Path $newMemory -Force | Out-Null
    Copy-Item -Path (Join-Path $sourceMemory "*") -Destination $newMemory -Recurse -Force

    $sourceJournals = Join-Path $SourceHome "EOT Journals"
    $newJournals = Join-Path $NewHome "EOT Journals"
    if (Test-Path $sourceJournals) {
        New-Item -ItemType Directory -Path $newJournals -Force | Out-Null
        Copy-Item -Path (Join-Path $sourceJournals "*") -Destination $newJournals -Recurse -Force
    }

    Write-Host "Copied memory -> $newMemory" -ForegroundColor Green
    Write-Host "Copied EOT Journals -> $newJournals" -ForegroundColor Green
    Write-Host ""

    # Flag, don't auto-rewrite: a regex replace across arbitrary memory
    # content risks corrupting something that was never meant to be a path.
    $suspects = Get-ChildItem $newMemory -Filter *.md | Select-String -Pattern 'Qualia/|Desktop\\|Desktop/' -List
    if ($suspects) {
        Write-Host "REVIEW NEEDED - these copied memory files mention a path that may be specific to the source, not this new home:" -ForegroundColor Yellow
        $suspects | ForEach-Object { Write-Host "  $($_.Path)" -ForegroundColor Yellow }
        Write-Host "(This is exactly the bug Teddy caught in eot-journal-convention.md on 2026-10-02 - a hardcoded 'Qualia/EOT Journals/' reference that didn't apply outside the Fenra repo.)" -ForegroundColor Yellow
    } else {
        Write-Host "No obviously source-specific paths found in copied memory - still worth a human skim." -ForegroundColor Green
    }
}

function Move-AIClone {
    <#
    .SYNOPSIS
      Renames and/or moves an existing AI home folder AND its matching
      .claude project directory together, in one step. Works for a pure
      rename (same parent, new name) or a full relocation (new parent) -
      mechanically identical.

    .NOTES
      Refuses to run if it can detect the destination already exists.
      Does NOT check whether a session is still open against OldHome - a
      locked folder will simply fail to move; close the session first.
    #>
    param(
        [Parameter(Mandatory)][string]$OldHome,
        [Parameter(Mandatory)][string]$NewHome
    )

    if (-not (Test-Path $OldHome)) {
        throw "OldHome does not exist: $OldHome"
    }
    if (Test-Path $NewHome) {
        throw "NewHome already exists: $NewHome - refusing to overwrite."
    }

    $oldKey = ConvertTo-ClaudeProjectKey -Path $OldHome
    $newKey = ConvertTo-ClaudeProjectKey -Path $NewHome
    $oldProjectDir = Join-Path (Get-ClaudeProjectsRoot) $oldKey
    $newProjectDir = Join-Path (Get-ClaudeProjectsRoot) $newKey

    if (Test-Path $newProjectDir) {
        throw "A project directory already exists at the computed destination key ($newProjectDir) - refusing to overwrite."
    }

    Move-Item -Path $OldHome -Destination $NewHome
    Write-Host "Folder moved: $OldHome -> $NewHome" -ForegroundColor Green

    if (Test-Path $oldProjectDir) {
        Move-Item -Path $oldProjectDir -Destination $newProjectDir
        Write-Host "Project directory moved: $oldProjectDir -> $newProjectDir" -ForegroundColor Green
    } else {
        Write-Host "No .claude project directory found at $oldProjectDir - nothing to move there (new/never-opened clone?)." -ForegroundColor Yellow
    }
}
