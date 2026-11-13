# Metal Roof Design Rules

This document records design constraints for parametric roof assembly
components, including panels and flashing.
Track implementation work in [TODO.md](./TODO.md).
For architecture, current behavior, validation expectations, and continuation
guidance, see [AGENT_HANDOFF.md](./AGENT_HANDOFF.md).

## Extension implementation guidance

- Keep all extension code under the existing `Examples::MetalRoofing`
  namespace unless performing a coordinated namespace migration.
- Keep extension registration in `src/metal_roof.rb`; implementation belongs
  under `src/metal_roof/`. Use `file_loaded?` / `file_loaded` guards for
  registration and menu creation.
- Load extension-owned Ruby files using `Sketchup.require`; use `require` for
  Ruby standard libraries and external dependencies.
- Resolve JSON assets through `Examples::MetalRoofing.support_path` in
  `src/metal_roof/support.rb`. Call it with asset names, not manually
  constructed parent-directory segments. Verify lookup when changing the
  asset layout or extension packaging.
- Keep repeated identical roof elements as component instances sharing a
  definition. Preserve inch units, SketchUp's Z-up coordinate system, and
  SketchUp geometry types.
- Keep model changes inside SketchUp operations and abort the operation before
  propagating a failure.
- Run geometry tests inside SketchUp with TestUp; standalone Ruby syntax
  checks do not validate SketchUp API behavior.

## Repeating roof elements

- Place repeated elements as component instances inside their relevant parent
  group. Keep identical geometry on a shared component definition so repeated
  quantities can be counted and estimated.
- Use a separate component definition when dimensions, profile, orientation, or
  geometry differ. Do not wrap each repeated instance in an extra group.
- Apply this rule to roof panels, ridge-cap segments, and future repeated roof
  assembly elements.

## Reloading the extension in SketchUp

Paste this into the SketchUp Ruby Console to reload the extension:

```ruby
load 'C:/Users/cedar/OneDrive/Documents/SKETCHUP/ROOFING_GUIDE_PROJECT/src/metal_roof/export_component_json.rb'
load 'C:/Users/cedar/OneDrive/Documents/SKETCHUP/ROOFING_GUIDE_PROJECT/src/metal_roof/main.rb'
```

## Flashing stock lengths and segmentation

- Flashing pieces have a maximum overall stock length of 120 inches, including
  their folds.
- Split any flashing run that exceeds the usable length of one stock piece.
- Apply this rule to ridge cap, gable flashing, eave drip flashing, apron
  flashing, and sidewall flashing.
- Preserve the required end treatments and joints when generating segments.

### Ridge cap pieces

- For a roof under 9 feet 6 inches long, use one continuous ridge-cap piece
  with a gable downturn at each end. Use the dedicated
  `json/ridge_cap_double_downfold.json` profile and resize only its straight span.
- A ridge-cap end piece has one gable downturn at the outer end and one
  standing-seam joint at the inboard end.
- Middle ridge-cap pieces use standing-seam joints to connect adjacent pieces.
- Keep each standing-seam joint outside an exclusion zone centered on every
  panel seam along the ridge. The zone is always 4 inches wide (2 inches of
  clearance on either side); its centers follow the panel module spacing, such
  as every 12 inches for 12-inch panels. Adjust paired joints symmetrically when
  possible; add another ridge-cap piece if the stock-length and seam-clearance
  constraints cannot otherwise be met.
- The first end piece's inboard upfold is 1 inch. Orient each middle piece so
  its 0.5-inch upfold meets the preceding 1-inch upfold and its 1-inch upfold
  meets the following 0.5-inch upfold. Select the final end profile with the
  complementary inboard upfold height required by the preceding piece. Use the
  native square 0.5-inch upfold profile when the joint calls for 0.5 inch.
- Upfold corners are square and perpendicular to the ridge face for 0.5-inch
  upfolds. Only 1-inch upfolds have 45-degree chamfered corners.
- Account for the 1-inch extension at each roof end and the 0.75-inch gable
  downturn when determining usable stock length. For segmented end pieces with
  a standing-seam joint, the maximum covered roof length is 9 feet 8.5 inches.
- Adjust the straight span to fit the roof; do not scale the fold or joint
  geometry to change piece length.
- For the 20-foot ridge-cap test roof, divide the 242-inch cap run into three
  equal 80 2/3-inch pieces: two end pieces and one middle piece. Keep the layout
  symmetric about the roof centerline.
