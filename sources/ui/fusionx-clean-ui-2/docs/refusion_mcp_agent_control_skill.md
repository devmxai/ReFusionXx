# ReFusion MCP Agent Control Skill

Status: `PMC-12`

This guide defines the safe authoring loop for AI agents using ReFusion MCP.

## Core Loop

1. Open session with minimal required capabilities.
2. Read state:
   - `refusion.get_security_profile`
   - `refusion.get_project_state`
   - `refusion.get_timeline_summary`
   - `refusion.get_selection`
3. Prepare mutation in dry-run mode.
4. Inspect diagnostics and patch preview.
5. Commit transaction.
6. Capture preview frame.
7. Validate diagnostics.
8. If needed: `refusion.undo_transaction` and retry.

## Mandatory Safety Rules

- Do not use UI automation as the primary path.
- Do not bypass transaction manager.
- Always provide `expectedRevision` for commit mode.
- Prefer minimal payloads to avoid size limits.
- Use `refusion.dry_run_command` for preflight.
- Read `refusion.get_security_profile` once per session and honor returned limits.

## Recommended Mutation Pattern

1. `refusion.insert_layer` (dryRun)
2. `refusion.commit_transaction` (commit)
3. `refusion.set_element_transform` (dryRun)
4. `refusion.commit_transaction` (commit)
5. `refusion.keyframe_edit` (dryRun)
6. `refusion.commit_transaction` (commit)

## SceneProgram Flow

1. `refusion.validate_scene_program`
2. `refusion.author_scene_program`
3. `refusion.apply_scene_program` in dryRun
4. `refusion.commit_transaction`

## Repair Flow

If output is visually wrong:

1. read timeline + selection
2. capture preview frame
3. patch transform/keyframes in dry-run
4. commit only if diagnostics improve
5. undo if regression appears

## What Not To Do

- No direct Stage5 mutation.
- No direct Live Scrub control path changes from MCP.
- No direct renderer/effects engine manipulation from MCP.
