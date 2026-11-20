# Changelog

What changed in each FIDE release, newest first. `tool/release.sh` adds each release's entry: one line per commit since the release before.

## 1.4.2 - 2026-11-20

- Release workflow signs the macOS build with Developer ID and notarizes it (hardened runtime, stapled ticket), so it opens without Open Anyway; README documents the signing secrets
- DRY review fixes: one Save (fixes ⌘S writing empty media files), one FileAction list, AI actions folded into Ask AI, shared side-panel tabs, stacked messages, toggle/badge/status-glyph/label consistency, token cleanup, shared non-UI helpers (imports, overlay analysis, parseDart, Debouncer, model/ARB/pubspec keys, SDK lookup)

## 1.4.1 - 2026-11-19

- Workspace gradient tints the panel surface with primary: brighter than the panels in dark mode (+20% contrast), darker blue in light mode up to the AA limit
- AI agent runs allowlisted flutter/dart/pod commands itself (run_command: pub chores, gen-l10n, fix, format, build_runner, pod) without a shell; Run tab's failed-build Errors offer Fix with AI

## 1.4.0 - 2026-11-19

- release.sh: push unpushed commits of main with the release instead of stopping; stop only when origin/main has commits not pulled
- Accessibility card on the Project Overview and an Accessibility view: elements judged at WCAG AA by kind and contrast range, each theme's color scheme and where it is defined, and every color the code writes, most used first
- accessibiility gate
- Every console output (Outdated Packages, Dependency Conflicts, Preview Failed, dart analyze) has a Clear button: OutputPanel.onClear is required, each owner drops its text
- Dependencies: keep Outdated/Conflicts output inside the section, and keep section header actions as icons in narrow panels (count hides, title ellipsizes) via PriorityRow.essentialTrailing
- Accessibility: every text and icon color reads at WCAG AA in both themes (solid badge/toast fills with white or black text via AppTheme.onFill, readable syntax colors incl. Atom One Light, visible operators, line numbers and hidden folders in onSurfaceVariant, subtler workspace glow under the title bar and settings, brighter terminal grey), guarded by color_contrast_test
- AI agent: an icon per step action (👓 read, ✏️ write, 🔍 search, 🔨 build…), tools answer with what the model would re-read for (edited lines, the code under each build error, where a failed replace's text is), replace_all for renames, and a 50-step cap
- AI panel: show each run of steps as one compact entry with repeats counted, stop clipping the hover copy toolbar, and stop the agent looping on a repeated call when nothing changed
- Fix Ollama "XML syntax error" on agent tool calls: check_build takes a parameter (qwen3-coder left parameterless calls unclosed), and retries tell the model its call was unreadable instead of resending the same request
- Faster local AI (analyze instead of build, bounded agent context, paged reads + search, streaming, warm-up, tool-call retry), opt-in Claude (in-app Anthropic sign-in or API key) / Bring-your-own AI providers in Settings › AI, and fix the template integration test's Ollama setup
- DRY follow-ups: one diff view (Git panel opens the editor's), one Upgrade via its quick fix, one pub outdated JSON model, Ollama readiness and setup shared with the wizard, Git refresh/push/pull ring from repo state, per-key Translate as an AI task, no spinners under ringing tabs, AppIcon.ai/fix and "… with AI" labels, Analyzer's "Repeated Widget Settings", one tooltip wait, "…" everywhere, shared URI/file/tree/path/config/version helpers, ProjectMetricsNotifier on PersistedNotifier
- DRY review: shared DropdownMenuButton, LoadingActionsProgress, RecentProjectIcon, DetailSection, CenterViewCloseButton, revealInFileManager; CommandRunner writes ✓/✗; Welcome buttons from AppCommand; real editor tooltip shortcuts; ReadableError, uniqueName, LocaleNumber.count, cached Dart SDK; drop dead Localize card, loading Retry, Preview "Clear" restart and OllamaInstaller.ensureReady
- Blue Update Button

## 1.3.0 - 2026-11-18

- fix build
- Add widget edits to the Outline's widget tree: Wrap with (Padding, Center, Expanded, SizedBox, Column, Row, Stack, Builder, or a named widget), Remove this widget, Swap with parent, Move up/down, formatted with the caret on the edited widget
- Fold the title bar's menus into one menu button when they don't fit beside the title (Linux and Windows), fixing the title bar overflow the Run menu caused at narrow windows

## 1.2.0 - 2026-11-18

- update "release.sh"
- Hot reload the app Run Debug runs: each save reloads it (restarting when a reload can't apply), Hot Reload/Hot Restart beside Stop and in a new Run menu (⌘\\ / ⇧⌘\\), apps run through a FlutterAppSession shared with Preview that stops them gracefully
- Make Info describe the selection (file, declaration with its callers and calls, widget preview) above project quality, and move package management into the Test tab
- Show the selected file's outline under its row in the Explorer and Organized trees, drop the Outline tab, make Info the first right tab describing the selected file then the project, and let a ringing tab's icon be the only spinner for its work

## 1.1.1 - 2026-11-18

- Panel toggles show or hide again instead of cycling Hide/Min/Max; ⌥-click a title-bar toggle to show its panel large
- Draw the image preview's color backdrop as soft spots of unrelated hues blended at random instead of a left-to-right rainbow, and rename it Blend
- Center the workspace glow on the middle of the active panel, measured where the layout puts it as panels hide, resize and the window or zoom change

## 1.1.0 - 2026-11-18

- update package - coverage: 1.16.1
- Auto update: check GitHub's latest release at launch and every 4 hours, announce it, and update in one click from the title bar or Settings, swapping the app once it quits and restarting it; Quit now exits on Windows too
- Ring the Preview, Analyzer, Info, Run and Test tab icons while their work runs, read through followBusy so a ring never starts the work it shows
- Outline the widget tree under each function returning widgets: widgets nested by the slot they fill, helper calls and widget variables as references
- Publish tagged releases straight away and delete the older ones in the Release job, so the README downloads always serve the latest build

## 1.0.2 - 2026-11-17

- A new build of 1.0.1, with no code changes

## 1.0.1 - 2026-11-17

- Name release builds without the version and link them from the README; publishing a release deletes the older ones, each Release run deletes earlier build artifacts
- Ring the AI tab icon while AI work runs (chat replies, tasks, Ollama setup): shared TaskRing, PanelTabSpec.busy, Ollama setup-running flag
- Add tool/release.sh to bump the pubspec version, check, build, tag and push; Release workflow checks the tag matches pubspec

## 1.0.0 - 2026-11-17

- First release: an IDE for Flutter projects with a project explorer, code and audio editors, live widget previews, build, run and test for each platform, Git, fCheck quality scores with quick fixes, localization, and a local AI assistant through Ollama
