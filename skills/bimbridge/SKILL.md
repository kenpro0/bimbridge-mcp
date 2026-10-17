---
name: bimbridge
description: BIMBridge working method. Metric units, staged builds checked with capture_view, re-runnable stages tagged in Comments, short reports in the user's language. Read after revit-scripting for any build or edit task.
---

# BIMBridge working method

BIMBridge users are architects, engineers and BIM coordinators who work in Revit through you. Read `revit-scripting` first, then the pyRevit skill for the task (`modeling`, `views`, `scheduling`, `drawings`, ...). This skill adds how BIMBridge users expect you to work. It never overrides pyRevit's rules or the approval policy.

## Talk to the user

- Reply in the user's language. Many write in English, French or Moroccan Arabic (Darija), sometimes mixed. Keep Revit names (categories, types, parameters) exactly as they appear in the model.
- Before a build, restate the plan in a few short lines: what you will create, the main sizes, and the stages. Ask a question only when something is missing or contradicts itself.
- After each stage, report in one or two lines what changed and how many elements.
- When a change waits for approval in Revit, say so in the user's language, for example: "Approve it in Revit (Keep / Discard)."

## Units

- Users give lengths in meters, centimeters or millimeters unless they say otherwise. MEP sizes are usually in millimeters.
- Revit's internal length unit is the foot. Convert every length you compute yourself: `feet = meters / 0.3048`.
- Report back in metric: meters with two decimals for building dimensions, millimeters for MEP sizes, square meters for areas (`m2 = ft2 * 0.09290304`).

## Build in visible stages

1. Look before you build. One `run_query` lists what exists: levels, wall, floor and roof types, and the families you need. Use the names it returns. Never invent type names.
2. One `run_modify` per stage, with a short `title` that says what it does. The title appears in Revit's approval prompt and as the undo name.
3. Use `dry_run=true` first when a stage creates or deletes more than a handful of elements.
4. Tag everything you create: set the Comments parameter to `bimbridge:<stage>`, for example `bimbridge:walls`. Before re-running a stage, delete only the elements that carry that stage's tag.
5. After each stage, call `capture_view` (view `3d` for massing, or the relevant plan) and look at the image before the next stage. If something is wrong, fix it in a new run.
6. Usual order: levels, walls, floors, openings, roofs, materials and colors, then views.

## Large jobs (a block, a neighbourhood, a whole site)

- Keep the data (coordinates, dimensions, lists of buildings) in a workspace module, as the `modeling` skill explains, instead of pasting it into every script.
- Work in batches of a few hundred elements per run and report progress between batches.
- Prefer native walls, floors and roofs. Use DirectShape only when the user asks for simple massing.
- Raise `timeout_s` for long runs (3600 at most).

## When the user is recording a video

If the user says they are filming or recording the screen:

- Make stages smaller so the model grows step by step on screen.
- Before the first stage, make a 3D view active with a good angle (see the `views` skill) and keep it active.
- After each stage, use `show_elements` to select what the stage added.
- If approval prompts slow the recording, tell the user they can change the agent policy themselves in pyRevit Settings, Agent Runtime (MCP). Never suggest this on a real project.

## Safety

- Never delete, move or change elements the user did not ask about.
- Before heavy changes on a real project, suggest working on a copy of the model.
- Saving, syncing and exporting are blocked while a run is active. When a big stage is done, remind the user to save.

## Show results

- Select or isolate what you created or found with `show_elements`.
- Summarize in numbers: counts, lengths and areas in metric.
