# FIDE - Flutter Integrated Developer Environment

FIDE is a lightweight, cross-platform Flutter IDE built with Flutter. It provides a clean, efficient development environment for Flutter applications with features like:

- Project explorer with file navigation
- Code editor with syntax highlighting
- Real-time preview
- Built-in terminal
- Git integration

## Features

- **Project Explorer**: Navigate your project files with ease
- **Code Editor**: Write and edit code with syntax highlighting
- **Real-time Preview**: See your changes as you code
- **Terminal**: Run Flutter commands without leaving the IDE
- **Git Integration**: Basic version control operations
- **Cross-platform**: Works on Windows, macOS, and Linux

## Getting Started

1. Clone this repository
2. Run `flutter pub get` to install dependencies
3. Run `flutter run` to start the app

## Building

To build for your platform, run:

- Windows: `flutter build windows`
- macOS: `flutter build macos`
- Linux: `flutter build linux`

## Contributing

Contributions are welcome! Please open an issue first to discuss what you'd like to change.

⸻

1 — High-level metaphors & UX pillars
 • Widget Ecosystem (primary metaphor) — Your project is an ecosystem made of organisms (widgets). You manipulate organisms’ form, behavior, and relationships instead of editing raw files.
 • Stages, Not Files — “Stages” are named working canvases (states of your app). Stages are what you tune, preview, record, and commit.
 • Time as Terrain — Changes are layered through time. Scrub, branch, and graft changes visually.
 • AI as a Crew Member — AI is an actor in the environment that performs proposals, refactors, testers, and verbalizes reasoning in context — not a chat box.
 • Gesture & Spatial Controls — Drag, pull, paint, lasso select, pinch to zoom, flick-to-commit.

⸻

2 — Main UI (no panels, no code editor-as-default)

Imagine a single continuous Canvas that fills the window. Everything happens on and around the Canvas.

 1. Left: Project Beacon Rail (compact vertical)
 • Tiny icons: Project, Stages, Version Map, Assets, Packages.
 • Tap reveals contextual micro-panels that slide over the Canvas (not docked).
 2. Center: The Canvas (primary working area)
 • The canvas is infinite and zoomable. It shows your App as a Stack of scenes (screens) laid out horizontally like stages in a theater.
 • Each scene is a live preview surface with its widget tree represented as tangible, nested shapes:
 • Containers are tiles
 • Columns/Rows are lanes
 • Buttons are chips
 • Animations are animated tiles
 • Tiles are draggable, nestable, and can be linked by connectors (call & data lines).
 3. Right: Inspector Orbit (contextual, circular)
 • When you select anything on the Canvas, a circular inspector appears orbiting your selection. It’s radial, gesture-friendly, and contains property rings you can twist/slide to adjust props (size, padding, color, animation speed).
 • The inspector is ephemeral — disappears when not needed.
 4. Bottom: Time Ribbon
 • A horizontal ribbon showing major checkpoints (snapshots, commits, branches). Scrub and the Canvas morphs to show that checkpoint’s state. Branches appear as forks in the ribbon you can drag and merge visually.
 5. Top: MicroCommands (minimal)
 • Tiny toolbar with Run, Snapshot, Test, Collaborate. Most commands are reachable via gestures or keyboard shortcuts; top bar is low-visibility.
 6. Floating: AI Crew (avatar + actions)
 • A small avatar that can be summoned and pinned. It can walk into a scene to run tests, propose refactors, or attach “advice tags” to widgets.

⸻

3 — Novel interactions (radically different controls)
 • Paint-to-Layout — Draw a rectangle on the canvas; drop a widget type and FIDE converts the drawn shape into a Container/SizedBox with same size and position.
 • Gesture Refactor — Draw a looping gesture around widgets to group; stretch the group outward to “extract” into its own widget file.
 • Drag-to-Connect — Drag from a widget’s data-port (small dot) to another widget to create a data binding. FIDE shows synthesized glue code (one-click accept).
 • Flick-to-Commit — Make a snapshot then flick it up into the Time Ribbon to create a commit. Flick-left = amend, flick-right = new branch.
 • Spatial Merge — When merging branches, FIDE overlays both canvases semi-transparently; you drag elements from branch B into branch A to accept changes. Conflicts show as glowing red tiles with suggested merges from AI.
 • Live Gesture Recording → Test — Record interactions on a device preview (taps, swipes). Save as a test with one click — it creates a widget test / integration test skeleton.
 • Semantic Lasso — Draw a lasso that selects widgets by semantics (e.g., “pick all Text widgets with large font”).
 • Natural Language Quick Edits — Hover select a widget and type “make this primary blue and raise elevation” — AI modifies props and offers the diff.

⸻

4 — Innovative Git UX integrated into the Canvas
 • Commit Story Cards: Each commit is a card with screenshot, short AI summary, tagged widgets changed, and test outcomes. Cards live in the Time Ribbon.
 • Widget-level Diff: Click a commit; FIDE highlights changed widgets (color keyed) and shows property diffs inline. You can accept/reject property changes per widget directly.
 • Branch-as-Layers: Branches are layered over the same Canvas; switch visibility to compare. Merge by dragging changes between layers.
 • Code-Authored by Design: Every structural design action produces a patch you can review. You can toggle to view raw generated Dart, but default is design-mode.
 • Peer Review Walkthrough: Reviewers navigate the Canvas & pin comments to widgets, not code lines. Comments can be resolved by code or design change.

⸻

5 — Developer workflows (example flows)

Flow A — Build a Screen

 1. Create Stage: “Login Flow v1”.
 2. Paint the screen layout; drop in TextFields & Buttons from radial palette.
 3. Use Spatial connections to wire Button → AuthService.
 4. AI suggests ListView.builder where lists are large. Accept.
 5. Record a quick interaction test and save to tests.
 6. Save snapshot and flick to commit. Add message (or AI generates one).

Flow B — Fix a Bug with Visual Diff

 1. Open Time Ribbon, scrub back to prior commit where bug didn’t exist.
 2. Overlay both states; see the changed widget (red highlight).
 3. Pull the prior property to current layer to revert only that change.
 4. Create a branch “fix/button-flash”; push.

Flow C — Code + Design Sync

 1. Developer prefers code — toggles one widget to code view (inplace editable Dart).
 2. Make change; Canvas updates live.
 3. Non-coder teammate drags new button into Canvas; FIDE updates Dart and shows diff.

⸻

6 — Architecture & tech stack (how to build it)
 • Frontend: Flutter (obviously) — prefer Flutter Desktop/Flutter Web for multi-platform dev.
 • Rendering: Canvas uses Flutter CustomPaint, InteractiveViewer, and/or Flame for performance.
 • Editor Integration: For raw Dart edit mode use flutter_code_editor or embed Monaco via WebView for web builds.
 • State & Persistence: Use a project file format (JSON + .dart source) with local DB (Hive) and optional Git backend (libgit2 via FFI for native).
 • Runtime Preview: Use flutter run in background for live preview (attach via VM service). For web, embed preview in iframe or run a hot-reloadable server with devtools hooking.
 • LLM/AI: Backend service that processes AST diffs and offers suggestions. Keep AI interactions optional and pluggable (can be local or cloud).
 • Testing Engine: Generate tests as Dart code; run using flutter test or integration_test.
 • Collaboration: Real-time collaboration via CRDTs (Yjs or automerge) over WebSocket. Use presence & avatars as ephemeral overlays.

⸻

7 — Data model (project serialization)

A lightweight JSON project format:

{
  "meta": {"name":"MyApp","created":"2025-09-10"},
  "stages": [
    {
      "id":"login-v1",
      "canvasItems":[
        {"id":"w1","type":"Container","props":{...},"pos":[120,80],"children":["w2","w3"]},
        ...
      ],
      "snapshots": [{"commit":"abc","timestamp":"...","screenshot":"snap1.png"}]
    }
  ],
  "assets": [...],
  "git": {"remote":"git@...", "branches":[...]}
}

Each canvas item has a sourceHint linking to the canonical file/line if it was code-originated for round-trip editing.

⸻

8 — Accessibility & Keyboard UX
 • Full keyboard mode: focus navigation across Canvas with arrows; Tab cycles widgets; Space opens radial inspector.
 • Screen reader mode: inspector reads properties and hierarchical context.
 • High-contrast theme & configurable font sizes.
 • Haptic/Audio feedback for operations (non-essential but helpful).

⸻

9 — Security & privacy
 • Projects stored locally by default. AI suggestions opt-in; logs are anonymized and can be disabled.
 • Git credentials stored in OS-native credential stores (Keychain/Windows Credential Manager).
 • Collaboration sessions are invite-only and encrypted (TLS).

⸻

10 — Roadmap: Minimum Viable Product → 1.0 → 2.0

MVP (4–8 weeks):
 • Canvas with nested tile representation for simple widgets (Container, Text, Row, Column, List).
 • Radial palette & drag/drop.
 • Live preview pane hooking to a hot-reload dev runner (basic).
 • Snapshot/save & Time Ribbon.
 • Export to generated Dart (single-screen).

v1.0 (3–6 months):
 • Full widget set & property inspector rings.
 • Widget-level diffs and commit cards.
 • Basic AI tips (local or API).
 • Gesture recorder → test generator.
 • Git integration (commit/push/pull/branch).

v2.0:
 • Real-time collaboration (CRDT).
 • Spatial merge & visual conflict resolution.
 • Rich AI features (refactor suggestions with explanation, code generation with provenance).
 • Cross-device staging and multi-device preview.

⸻

11 — Example UI mock descriptions (for designers/devs)

 1. Stage Overview: Top-left shows tiny thumbnails of stages. Canvas shows Stage “Login” centered. Widgets are soft-glow tiles with icons and short labels. Selection ring animates around selected tile. Time Ribbon shows commits as circular cards with tiny screenshot thumbnails.
 2. Inspector Orbit: When a tile is selected, a semi-transparent circular dial appears around it with 4 rings: layout, style, behavior, accessibility. Dragging a ring rotates rates (e.g., animation speed), tapping the style ring opens color swatches.
 3. Merge Playground: Two semi-transparent layers; conflicts appear as red pulsating tiles with AI suggestions popping up as small “post-its”.

⸻

12 — Unique selling points (why devs would switch)
 • Extremely visual and tactile for UI-first development.
 • Fast iteration with Time Ribbon + snapshotting + visual diffs.
 • Seamless design ↔ code round-trip.
 • Widget-level Git UX tailored to Flutter’s characteristics.
 • Natural onboarding for designers and PMs to participate (they can edit UI directly).

⸻

13 — Optional add-ons / experiments
 • Sonic Debugger: Map CPU/complexity to sound and color for profiling hotspots.
 • Composable Assets Marketplace: Drag components from an online marketplace into Canvas and accept license.
 • Playgrounds: Small, shareable stage snippets that embed in docs or PRs.

⸻

14 — Next practical steps I can do for you right now

Pick one and I’ll produce it immediately:
 • Build a runnable Flutter skeleton of the Canvas + Radial Palette + Inspector Orbit (prototype code).
 • Create a set of high-fidelity mock screens (JSON + descriptions) for designers.
 • Produce the JSON project schema + a converter that generates Dart from Canvas data model.
 • Draft the Git widget-diff UI mock as a detailed screen-by-screen flow.
