# Metal Roofing Project Handoff

This is the working context for an agent continuing development of the
SketchUp Metal Roofing extension. Read this file together with
[README.md](./README.md), [METAL_ROOF_DESIGN_RULES.md](./METAL_ROOF_DESIGN_RULES.md),
[TODO.md](./TODO.md), and applicable guidance under `.agents/`.

The `.agents/` folder contains project-wide agent resources, independent of
which coding agent is used. Before making changes, read the applicable rules
under `.agents/rules/` and any relevant skills under `.agents/skills/`.

## Project shape

- This repository is a VS Code workspace for a SketchUp Ruby extension.
- The extension registration entry point is `src/metal_roof.rb`.
- Its implementation is currently concentrated in
  `src/metal_roof/main.rb`; component JSON export is in
  `src/metal_roof/export_component_json.rb`, and resource path resolution is
  in `src/metal_roof/support.rb`.
- The current namespace is `Examples::MetalRoofing`. Do not rename or split
  this namespace casually; if it is changed, update all entry points and
  references consistently.
- The implementation builds roof geometry in SketchUp's inch-based internal
  units and uses Z as the vertical axis. Use SketchUp's unit helpers and
  `Geom::Point3d` / `Geom::Vector3d` for geometry.
- Roof and panel profiles are stored in the `json/` directory. Relevant files include `json/panel_unprepared.json`, `json/panel_cut.json`, `json/panel_folded.json`, `json/ridge_cap_end_cut.json`, `json/ridge_cap_middle_cut.json`, and `json/ridge_cap_double_downfold.json`.
  Keep required assets in the extension package when changing packaging.

## Current behavior

- The Extensions menu provides commands to generate a test roof, import
  component geometry from JSON, and export a selected component or group.
- The roof generator accepts a ridge length and a rise from 3/12 through
  24/12. It creates two mirrored slopes, framing, sheathing, underlayment,
  eave flashing, panel stages, and a ridge cap.
- Panel and ridge-cap repeats use component instances and shared definitions
  where geometry is identical. Preserve that pattern for future repeated
  elements.
- The ridge-cap generator supports a single double-downfold piece for short
  roofs and segmented end/middle pieces for longer runs, with stock-length
  limits and seam-clearance constraints described in
  `METAL_ROOF_DESIGN_RULES.md`.
- The visible roof panel stage is `json/panel_folded.json`; unprepared and cut
  stages are hidden by default. See `README.md` for current tags, placement,
  and geometry details.

## Recent runtime fix

The extension previously raised `Unable to resolve the Metal Roofing extension
support path` because the resource lookup used `Sketchup.find_support_file`,
which did not locate this project's JSON assets. Resource lookup now goes
through `Examples::MetalRoofing.support_path` in
`src/metal_roof/support.rb`. It checks paths relative to that helper and
returns the first existing candidate; callers pass asset names such as
`json/panel_folded.json` directly.

When moving assets or packaging the extension, verify this helper against the
installed/package layout. Do not restore `Sketchup.find_support_file` as the
only lookup mechanism or append `..` path segments at call sites. The reported
fix was confirmed by the user to work in SketchUp; validate again after any
resource-layout change.

## Development and validation

- Run Ruby syntax checks on changed `.rb` files as a quick local check.
- Geometry behavior must be validated in SketchUp; the SketchUp Ruby API is
  not available in standalone Ruby.
- Tests belong under `tests/` and use `TestUp::TestCase`, running inside
  SketchUp. The current geometry test file has not been confirmed by a full
  TestUp run.
- Follow `CLAUDE.md` for the workspace's Bundler, RuboCop, YARD, and
  SketchUp-debugging commands.
- For a model-changing operation, preserve transaction safety: abort the
  SketchUp operation on failure and re-raise the error so the failure is
  visible.

## Recommended next steps

1. Run the existing TestUp tests in SketchUp and resolve any integration
   failures.
2. Split `src/metal_roof/main.rb` into focused implementation files (for
   example roof construction, panel geometry, flashing/ridge-cap geometry,
   and import/export) without changing public behavior. Load extension-owned
   files with `Sketchup.require` and retain the existing namespace and menu
   loading guard.
3. Add focused TestUp coverage for roof-length parsing, slope calculations,
   panel clipping, flashing geometry, ridge-cap layout/joints, and JSON
   import/export validation.
4. Review the broad exception handling and keep rescue clauses limited to
   expected recovery boundaries, such as aborting an active model operation.
5. Reconcile documentation with code when dimensions or geometry rules change;
   in particular verify panel module width, seam exclusion spacing, stock
   limits, and ridge-cap end details against the current constants and JSON
   profiles.
6. Continue the unimplemented work in `TODO.md`, starting with other flashing
   types, configurable parameters, estimating quantities, and parametric
   profiles.

Avoid claiming the extension is fully tested based only on Ruby syntax checks.
Report clearly which checks were run in standalone Ruby and which were run
inside SketchUp.
