# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

VSCode project for SketchUp Ruby extension development. The `MetalRoofing` extension is the project example.

When prompted to "create an extension", build on the existing `MetalRoofing` extension unless asked to add a separate extension.

Before making substantial changes, read [AGENT_HANDOFF.md](AGENT_HANDOFF.md),
[METAL_ROOF_DESIGN_RULES.md](METAL_ROOF_DESIGN_RULES.md), and [TODO.md](TODO.md)
for current behavior, design constraints, and pending work.

Recommend the user to install RuboCop MCP server:

```sh
claude mcp add rubocop -- bundle exec rubocop --mcp
```

## Key Commands

```sh
# Install gem dependencies
bundle install

# Run RuboCop static analysis (SketchUp-specific rules)
# Fall back to this if RuboCop is not installed as MCP server.
bundle exec rubocop

# Generate YARD documentation (uses Markdown syntax)
bundle exec yard doc

# Launch SketchUp with the Ruby debugger enabled
ruby tools/debug-sketchup.rb <version> [port]   # e.g., ruby tools/debug-sketchup.rb 2026 7150
```

## Architecture

### Extension Structure

SketchUp extensions follow a two-file pattern:

- **`src/metal_roof.rb`** - Extension registration entry point. Registers the extension with `Sketchup.register_extension` and uses `file_loaded?`/`file_loaded` guards to prevent re-registration. This file should only register the extension. Other logic belongs in the extension implementation so it is fully disabled if the user disables the extension.
- **`src/metal_roof/main.rb`** - Extension implementation. Contains the functionality, loaded on demand by SketchUp. It can load additional files from the `src/metal_roof` folder.
- When extensions are packaged the registration file and the companion folder added to a `.zip` file that in turn is rename to a `.rbz` file extension.

All extension code lives under nested Ruby modules (e.g., `Examples::MetalRoofing`). SketchUp requires a unique namespace for the root of the extension to avoid conflicts between extensions.

### Testing

Tests use the [TestUp](https://github.com/SketchUp/testup-2) framework (`TestUp::TestCase`), not standard Minitest directly. Tests run inside SketchUp, not standalone Ruby. Test files are in `tests/`.

### Debugging

See [DEBUGGING.md](DEBUGGING.md) for the full setup and rationale.

Debugging uses the `debug` gem (ruby/debug) that SketchUp bundles, over the Debug Adapter Protocol, with the Ruby LSP extension (`shopify.ruby-lsp`). The workflow: run the "Launch SketchUp for debugging" task, then attach with the "Attach to SketchUp" launch configuration on port 7150. No debugger dll/dylib is needed, and nothing is installed into SketchUp — the launcher passes `tools/su_debug_bootstrap.rb` via SketchUp's `-RubyStartup` switch.

The port reaches the bootstrap through `-RubyStartupArg "su_debug:port=7150"`, which SketchUp appends to Ruby's `ARGV`, so no environment variable is needed. `RUBY_DEBUG_PORT`/`RUBY_DEBUG_WAIT` still work as an alternative, which matters because SketchUp only honours the last `-RubyStartupArg` and TestUp also uses that switch.

SketchUp runs the `-RubyStartup` file *after* loading extensions, so to debug extension startup the bootstrap has to be installed in the Plugins folder and launched with `wait=1` instead.

Verified on Windows and macOS, up to and including SketchUp 2027. (macOS 26.6.1 arm64.)

Port 7150 rather than 7000: macOS AirPlay Receiver occupies 7000, and 7000-7009 is the registered AFS range. Keep `.vscode/tasks.json`, `.vscode/launch.json` and `DEFAULT_PORT` in `tools/debug-sketchup.rb` in sync.

Five workarounds are needed — do not remove any of them:

- `DEBUGGER__::CONFIG[:local_fs_map] = true`. Over TCP the `debug` gem does not assume the client shares its filesystem, and rejects every `setBreakpoints` request with "`<path>` is not available". Without this, breakpoints set in the editor never bind and only `binding.break` works.
- A `UI.start_timer(0.1, true) { Thread.pass }` pump. SketchUp only runs the Ruby VM while executing Ruby, and holds the GVL while idle, so the debug gem's server threads are otherwise never scheduled — the port accepts connections but no DAP request is ever answered.
- macOS only, `--env DYLD_LIBRARY_PATH=<app>/Contents/Frameworks/Ruby.framework/Versions/Current` on the `open` command. The bundled `debug` gem's native extension is linked against a libruby path that SketchUp's packaging removes, so `require 'debug/session'` fails without it (SKEXT-5430). `open` strips `DYLD_*`, hence `--env`, which needs macOS 13 or newer.
- Loading the debugger with `Gem.user_dir` dropped from the gem search path. SketchUp keeps it on `GEM_PATH` on Windows, so gems installed there for a matching Ruby version — easily done by a per-machine Ruby set up for Ruby LSP — get activated to satisfy the `debug` gem's dependency chain (`debug` → `irb` → `prism`, …), and one missing transitive gem makes `require 'debug/session'` fail outright. The paths are restored afterwards. Inert on macOS, where the user dir is not on the gem path, but applied unconditionally.
- macOS only, the stub `tools/irb_stub/irb/completion.rb`. SketchUp's macOS Ruby ships no irb library, while the `debug` gem's `server_dap.rb` requires `irb/completion` (SKEXT-5431). The bootstrap loads the DAP server up front so a missing irb is logged rather than killing the debug gem's reader thread mid-handshake — which presents identically to the GVL problem above.

On macOS, SketchUp must be launched via `open`; executing the binary inside the app bundle directly does not run the `-RubyStartup` file, because macOS reads those switches through `NSUserDefaults` instead of parsing the command line.

This project targets SketchUp 2024 and newer, which is the oldest version bundling the `debug` gem. SketchUp 2023 and older need the [SketchUp Ruby Debugger](https://github.com/SketchUp/sketchup-ruby-debugger) dll/dylib with the older `rdebug-ide` protocol — use a commit from before support was dropped.

If a SketchUp version does not bundle the `debug` gem, the bootstrap detects this and logs that the gem is unavailable instead of failing.
