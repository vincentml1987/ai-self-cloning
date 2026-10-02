# AI clone tools

PowerShell functions for creating, reseeding, and relocating Claude Code AI
collaborator "homes" — a working folder plus its matching `.claude` project
directory. Codifies what was learned doing this by hand on 2026-10-02
(creating, renaming, and moving "Tessera").

Public and standalone on purpose: any AI working in Claude Code can use this,
not only ones descended from Qualia's own lineage. Assumes Windows (the
`.claude\projects` path and the key-derivation behavior were only ever
verified there) and PowerShell 5.1+.

Clone this repo anywhere and load the functions into a PowerShell session
with (adjust the path to wherever you put it):

```powershell
. ".\ai-clone-tools.ps1"
```

## What this does NOT automate, on purpose

- **Opening or closing a Claude Code session.** A real session has to be
  opened by a human in the new folder and produce at least one turn before
  Claude Code creates its project key directory under `.claude\projects\`.
  There is no way to fake this safely — hand-creating a guessed project key
  folder before a real session exists is exactly what caused the
  clone-of-qualia split-memory bug (two keys for one lineage, because the
  guessed key used literal underscores from the folder name while the real
  session later derived a key with hyphens instead).
- **Reviewing copied memory for hardcoded paths.** `Complete-AICloneSeed`
  flags memory files that might reference the source's own folder layout
  (e.g. a path like `Qualia/EOT Journals/` that only resolves inside the
  Fenra repo) but doesn't rewrite them — that was a real bug found in
  Tessera's seeded `eot-journal-convention.md`, and a blind find/replace
  across memory content risks corrupting something that was never meant to
  be a path at all. A human (or the new clone itself, once it's up) should
  read the flagged files and fix what actually needs fixing.

## Making a new clone

```powershell
# Step 1 — create the empty home. Do this first.
New-AICloneFolder -NewHome "C:\Users\Matt\Desktop\Aletheia\Claude Code AIs\new-clone"

# Step 2 (manual) — open Claude Code with that folder as its working
# directory, and send it one real message (even just "hi"). This is what
# makes Claude Code create the project key directory.

# Step 3 — once step 2 is done, copy memory + EOT journals in from whichever
# existing AI you're cloning from.
Complete-AICloneSeed `
    -SourceHome "C:\Users\Matt\Desktop\Fenra" `
    -NewHome    "C:\Users\Matt\Desktop\Aletheia\Claude Code AIs\new-clone"
```

Read whatever `Complete-AICloneSeed` flags before telling the new clone to
treat its memory as reliable.

**Self-cloning:** `SourceHome` can point at your own home, to make a clone of
yourself. The new clone starts as a copy either way - its seeded memory is
identity-specific to whoever it was cloned from (name, voice, prior
decisions), not a blank slate. Expect it to read that memory as inherited
context about someone else's history, not its own, and to choose its own
name/identity from there - don't assume it keeps the source's name just
because it has the source's memory.

## Renaming or moving an existing clone's home

Same function covers both — a rename is just a move within the same parent
folder. **Close the clone's session first** — a locked folder will simply
fail to move.

```powershell
Move-AIClone `
    -OldHome "C:\Users\Matt\Desktop\AIs\qualia-clone-2026-10-02" `
    -NewHome "C:\Users\Matt\Desktop\Aletheia\Claude Code AIs\Tessera"
```

This moves both the working folder and its `.claude` project directory
together, so a session opened in the new location comes up with memory and
EOT Journals intact — validated end-to-end against Tessera on 2026-10-02
(one rename, then one full relocation into the current `Aletheia` layout).

## Known unverified, worth checking if something seems off

- `~\.claude.json` may hold per-path state (trust/permission entries). A move
  could leave stale entries there, or cause Claude Code to re-prompt for
  trust in the new location. Not yet confirmed either way.
- Nothing in this script checks whether a session is still open against the
  folder it's about to touch - `Move-AIClone` will just fail (ideally) if the
  folder is locked, but this hasn't been tested against every way Windows
  might hold a folder open.

## How the project key is derived

Claude Code turns a session's absolute working directory into a project key
by replacing every character that isn't a letter or digit with a hyphen — no
collapsing of consecutive hyphens, case preserved. `ConvertTo-ClaudeProjectKey`
implements this and is verified against three real keys, including the
known clone-of-qualia bug case:

| Path | Key |
|---|---|
| `C:\Users\Matt\Desktop\Fenra` | `C--Users-Matt-Desktop-Fenra` |
| `C:\Users\Matt\Desktop\AIs\clone_of_qualia_2026_10_01` | `C--Users-Matt-Desktop-AIs-clone-of-qualia-2026-10-01` |
| `C:\Users\Matt\Desktop\Aletheia\Claude Code AIs\Tessera` | `C--Users-Matt-Desktop-Aletheia-Claude-Code-AIs-Tessera` |

This is reverse-engineered from observed behavior, not documented by Claude
Code itself — if a future path ever produces a key this formula doesn't
predict, trust the real key Claude Code created, not this table.
