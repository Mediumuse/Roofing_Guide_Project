# Future To-Do

- [ ] add all other flashing pieces in all slopes: gable, valley, hip, pans,
  sidewall, apron
- [x] Add folded ridge-cap end and middle profiles and generate the needed
  segments and joints according to [Metal Roof Design Rules](./METAL_ROOF_DESIGN_RULES.md).
- [ ] Segment gable flashing, apron, and sidewall runs to respect
  stock lengths and their required joints and end treatments in [Metal Roof
  Design Rules](./METAL_ROOF_DESIGN_RULES.md).
- [ ] add custom panel peices like split panels aroung penetrations
- [ ] add parameter setting menu to set various parameters dimensions of the panels, flashing pieces, roof span, length, pitch, penetrations, etc...
- [ ] include estimating features like number of panels, lineal length needed, area covered by underlay and sheathing, number of flashing pieces and the lineal amounts
- [ ] Clean and review the code for readability, efficiency, consistent component
  metadata (dimensions, materials, and tags), and parametric, algorithmic
  patterns that anticipate future additions.
- [ ] improve the sketchup to AI translation of profiles or components into working code

- [ ] Add automated geometry tests for roof layers, flashing profiles, panel
  clipping, fold thickness, and extrusion validation.
- [ ] Review and improve error messages shown when panel JSON files are missing
  or contain unsupported geometry.
- [ ] Generalize JSON profiles into parametric component definitions.
- [ ] Document the panel-stage JSON export workflow and required file format.
- [ ] Evaluate adding user controls for roof width, horizontal run, and panel
  dimensions.
  - [ ] Run the TestUp suite in SketchUp to lock in design rules; the tests
    use `TestUp::TestCase` rather than standalone Minitest.

## Agent continuation

Read [AGENT_HANDOFF.md](./AGENT_HANDOFF.md) before making substantial changes.
The ridge-cap segmentation task above is implemented in the current generator;
it still needs ongoing in-SketchUp regression coverage. The remaining flashing
types, TestUp coverage, configurable parameters, quantity estimates, and
parametric profiles are future work.