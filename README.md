# VSCode Project for SketchUp Extension Development

This is a boiler plate example project for setting up a VSCode project for SketchUp extension development.

Key features of this setup:

* When opening the project in VSCode you will be presented with a recommended set of VSCode extensions if you are missing any.
* Configured for Ruby auto-complete and code insight.
* SketchUp Ruby API supported in auto-complete.
* VSCode tasks for debugging Ruby source in SketchUp.
* Inline static analysis powered by RuboCop and RuboCop SketchUp.

![](https://github.com/SketchUp/sketchup-ruby-api-tutorials/wiki/images/VSCode/VSCodeSolargraphAutoComplete.png)

## Prerequisites

* Standalone Ruby installed on your development system. See [rubocop-sketchup manual](https://rubocop-sketchup.rerubyadthedocs.io/en/stable/installation/) for more details.
* The [Bundler gem](http://bundler.io/) to manage gem dependencies.

## Getting started

1. Clone the project to your machine.
2. From the command line install the require gem dependencies: `bundle install`
3. Start coding!

### Test extensions directly from the project

The SketchUp 2027 development loader scans the project's `src` directory at
startup and loads every top-level `.rb` file as an extension registration
entry point. Add each new extension's registration file there; keep its
implementation in a same-named companion subdirectory and load it through
`SketchupExtension.new`. Restart SketchUp to load newly added entry points.
The single-extension RuboCop file-structure check is disabled for this
multi-extension workspace.

The Metal Roofing extension registers a **Extensions > Generate Test Roof
Assembly** command. Choose a ridge length and pitch to create the sample roof
assembly in the active model; the default ridge length is 17 feet. Running it
replaces the previous generated **Metal Roof Assembly**,
so updated panel exports do not overlap older geometry. The assembly contains
two equal roof slopes mirrored across a vertical plane at the ridge, and can be
selected as one group. It uses
`json/panel_folded.json` for the visible roof panels. The
`panel_unprepared.json` and `panel_cut.json` stage geometry is added on the
hidden **Panel - Unprepared** and **Panel - Cut** tags. Toggle those tags to
show each stage; the visible folded stage is on the **panel-folded** tag. Save
scenes for viewport exports. Repeated roof elements are component instances
inside their parent groups, with identical pieces sharing definitions, so they
can be counted and used for quantity estimates. This applies to panels and
ridge-cap pieces and is the standard for future repeated roof elements. The
current sample roof is 17 feet wide along the ridge (X axis), with the ridge cap
extending 1 inch beyond each panel end for a total cap length of 17 feet 2
inches. This layout uses two equal 103-inch end pieces, within the 120-inch
stock limit. Keep the three panel-stage JSON files plus
`json/ridge_cap_end_cut.json`, `json/ridge_cap_middle_cut.json`, and
`json/Ridge_Cap_End_-_Right_with_0.5_square_foldup.json` in the `json/` directory beside
this README. For roofs under 9 feet 6 inches, the generator uses one ridge-cap
piece with a downturn at each gable; provide its profile as
`ridge_cap_double_downfold.json`. Folded-panel geometry
is used without altering its exported hem dimensions, and its inner fold edge is
positioned against the eave flashing to match the exported placement.
Imported panel points are rounded to six decimal inches, and shared coplanar
edges and redundant collinear points are removed without softening or
smoothing faces. The sample roof has a 4-foot horizontal run and defaults to a
6/12 pitch. Enter any integer rise from 3/12 through 24/12 in the generator
prompt; framing plumb cuts, roof slope length, flashing offsets and bends, and
panel clipping are recalculated for that pitch. The panel stages end 1 inch
short of the underlayment's upper edge, measured along the slope. The ridge-cap
cut profiles are adapted to the selected pitch while preserving their fold
details. The final end profile is selected to give the complementary joint
height without scaling its fold geometry. Their straight spans are
length-adjusted to make equal segments while preserving the start and end
feature widths. The end piece is
mirrored at the left gable so its downturn faces outward. Pieces are oriented
so each 1-inch standing-seam upfold meets a complementary 0.5-inch upfold; the
final end piece's native profile matches the preceding piece. The 0.5-inch
upfold has square corners perpendicular to the ridge face; only 1-inch upfolds
have 45-degree chamfered corners.
The cap extends 1 inch beyond each
end of the panel field. Its material matches the panels, and its sheet thickness
is 0.05 inch. Its pitch-dependent placement aligns the underside with the
1.5-inch standing-seam tops. The cap is translated vertically by the seam
height divided by the pitch cosine so the perpendicular offset from the roof
plane remains 1.5 inches. Its downslope reach is adjusted relative to the
underlayment's upper edge to provide 4 inches there, or 3 inches beyond the
panel ends, measured along the roof surface at every supported pitch. The
folded-stage JSON is checked
for longitudinal edges that drift more than 0.001 inch across at least 4 inches
of roof run, which can reveal tapering or skewed extrusion.
The assembly, framing, sheathing, underlayment, eave flashing, and ridge cap are
assigned to separate **roof**, **framing**, **sheathing**, **underlay**,
**eave-flashing**, and **ridge-cap** tags.

### Export and import component geometry

Select a group or component and choose **Extensions > Export Selected
Component to JSON**. Enter a component name and choose where to save the JSON.
Alternatively, run `tools/create_component_json.rb` in SketchUp's Ruby Console.

To import geometry, choose **Extensions > Import Component from JSON**, select
an exported file, then set the imported component name, tag, material, and
model-space origin. Geometry coordinates are interpreted in inches; the
export's saved instance transform is not applied, so the component can be
placed independently of its source model.

The Ruby Console export command is:

```ruby
load 'C:/path/to/ROOFING_GUIDE_PROJECT/tools/create_component_json.rb'
```

The exporter records face front/back material names, colors, and transparency.
The importer reuses materials already in the model, restores exported material
properties when creating missing materials, and uses the selected material for
faces without one. It supports
single-loop faces and planar polygons, plus non-planar quadrilateral faces
which it triangulates. Faces with inner loops are reported as unsupported.
Imported geometry is a static component, not a parametric profile; dimensions
and geometry must still be defined by code to support automatic resizing.

## Configuration

You might want to review the various configuration files to fit your project needs:

### `.rubocop.yml`

Configure what RuboCop should look for when analyzing your project. There are comments inline in the configuration file offering some help with what is pre-configured. For more details refer to the  [rubocop-sketchup manual](https://rubocop-sketchup.readthedocs.io/en/stable/).

### `.solargraph.yml`

You might want to update the `require_paths` to reflect one of your SketchUp installation paths to ensure Solargraph is able to provide full auto-complete for the SketchUp API.

### `.vscode/tasks.json`

Add/remove task launchers for relevant SketchUp versions. Follow the pattern for the existing launchers.

### `.editorconfig`

You might want to adjust this configuration file to suit your own coding style. This file is a [generic config file](https://editorconfig.org/) supported by many code editors.

## How To

### Debug in SketchUp

![](https://github.com/SketchUp/sketchup-ruby-api-tutorials/wiki/images/VSCode/VSCodeDebugging.gif)

Debugging uses the [Ruby LSP][ruby-lsp] extension and the `debug` gem that
SketchUp bundles. No debugger dll/dylib is needed, and nothing has to be
installed into SketchUp — the launcher passes the debug bootstrap to SketchUp via
its `-RubyStartup` command line switch. See **[DEBUGGING.md](DEBUGGING.md)** for
the details, including how to debug extension *startup*.

Requires SketchUp 2024 or newer.

You also need to make sure you are [loading the extension](https://github.com/SketchUp/sketchup-ruby-api-tutorials#loading-directly-from-the-repository) directly from your project's directory.

The short version:

1. Set break points in the gutter bar next to the line numbers in the editor.
2. `View > Command Palette` (`Ctrl+Shift+P`)
3. Start typing `task`
4. Pick `Tasks: Run Task`
5. Pick `Launch SketchUp for debugging`
6. Pick the version of SketchUp to launch (e.g. `2026`)
7. Wait for SketchUp to launch.
8. Go to the Debug tab in VSCode (`Ctrl+Shift+D`)
9. Pick `Attach to SketchUp` in the drop-down.
10. Click the `Start Debugging` button.

For SketchUp 2023 and older, use a commit from before this project dropped
support for them. Those versions do not bundle the `debug` gem and need the
[SketchUp Ruby Debugger][su-debugger] dll/dylib with the deprecated
`rebornix.ruby` extension.

[ruby-lsp]: https://github.com/Shopify/ruby-lsp
[su-debugger]: https://github.com/SketchUp/sketchup-ruby-debugger

## Further Reading

For the latest information on setting up rubocop-sketchup integration with VSCode, refer to:

* https://rubocop-sketchup.readthedocs.io/en/stable/integration_with_other_tools/
* https://github.com/SketchUp/sketchup-ruby-api-tutorials/wiki
