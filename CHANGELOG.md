# Changelog

What changed in each FIDE release, newest first. `tool/release.sh` adds each release's entry: one line per commit since the release before.

## 1.5.1 - 2026-11-23

- AI panel: pick the local model in its footer among MiMo 9B (default, 16 GB+), Qwen3 Coder 30B and Qwen 3.8 27B (32 GB+), picking one not downloaded downloading it; a question stopped by its step cap or a repeated call is answered from what the model read, in one last request offered no tool; the agent benchmark (FIDE_AI_BENCH, FIDE_AI_MODEL) measures any model
- AI commit message: the digest tells code moved, renamed or removed (declarations, tests) instead of reading it as added, and the message starts with an area or a verb as the project's recent subjects do; the replay test takes another repo and its staged change (FIDE_AI_REPLAY_REPO, FIDE_AI_REPLAY_STAGED)
- Widget States check (under evaluation in FIDE) with its one-click Fix States: the State beside its widget, the methods tests call that use nothing of it moved out for them to call, every other test statement reaching into it removed, and the State made private with State\<Foo> createState(), through Split Classes' planner; tasks changing the project's files (quick fixes without the AI, Split, the Analyzer tab's Move and Fix) block the app with BlockingTaskDialog, showing their step and Cancel, which stops them before the next file is written; ignore comments and findings of FIDE's checks read a declaration's line after its doc comment; the Analyzer tab's badge counts what its reviews found
- Widget States check (under evaluation in FIDE): a State apart from its widget, or public with no file of the app naming it, and each test reaching into one, an error, are quality issues Fix States fixes in one click through Split Classes' planner (statesOnly): it moves the State beside its widget, deleting the part file it empties, moves out the methods tests call that use nothing of it so they call them directly, removes every other test statement reaching into it with the tests, hooks, groups and imports left empty, and makes it private with State\<Foo> createState(), refusing what wouldn't compile; ignore comments and findings of FIDE's checks read a declaration's line after its doc comment; a quick fix writing nothing reports as info; the Analyzer tab's badge counts what its reviews found (follow, shared with followBusy)
- Widget States check (under evaluation in FIDE): a State apart from its widget, or public with no file of the app naming it, is a quality issue Fix States fixes, moving it beside its widget and making it private through Split Classes' planner (statesOnly), which deletes the part files it empties and honors the check's ignore comment; a widget's State is private to its widget, so each test line reaching into one is an error, "Tests reaching into States", explaining why and how to check the widget instead, with no AI fix (qwen3-coder swapped the checks for findsOneWidget); ignore comments and findings of FIDE's checks read a declaration's line after its doc comment; a quick fix writing nothing reports as info, not success; the Analyzer tab's badge counts what its reviews found, following them without starting one (follow, shared with followBusy)
- Widget States check (under evaluation in FIDE): a State apart from its widget, in a part file or a library of its own, or public with no other file naming it, is a quality issue on the overview, Info panel and light bulb; Fix States moves it beside its widget and makes it private through Split Classes' planner (statesOnly), which now deletes the part files it empties; the Analyzer tab's badge counts what its reviews found, following them without starting one (follow, shared with followBusy)
- Widgets and their State: a stateful widget's State is private and part of its widget everywhere (WidgetStates), Split Classes makes a public State private instead of moving it and moves a widget with its State, a project-wide Split Classes quick fix on the One class per file issue, which lists its files and explains the rule and its ignore comment, Repeated Widget Settings names a State's place after its widget, MainLayout's State private in its file, Rename's usage visitor shared (NameUses, NameLocator)
- DRY review: the tree's Rename points imports at the new name as File Layout's moves do, one way to open a file (openItem) and to check the project again (ProjectRefreshButton), hardcoded strings offer one AI fix, Repeated Widget Settings types renamed from Dry\*, ProjectPaths.relativeOf/absoluteOf, one name per action and every button and menu label in Title Case

## 1.5.0 - 2026-11-22

- Editor: CodeForge gets the SDK's Material localizations again (SdkMaterialLocalizations), imported from the SDK's own library so dart fix no longer rewrites them to material_ui's
- Analyzer tab: Repeated Widget Settings shows each place in a view or a widget, with File Layout's glyphs, told apart as File Layout does (FileLayoutAnalyzer.viewsOf), never by folder
- Git panel: a moved or renamed file is one row, new ← old path, staged or not (git pairs unstaged moves on a copy of the index), with its real line counts and diff, Stage/Unstage/Discard acting on both ends; File Layout moves, Split Classes and Repeated Widget Settings never add a Layers issue (ImportGraph judged by fCheck's validateLayers)
- AI commit message: the model reads a digest of the whole staged change (files, docs and declarations added, test names, then code) and the project's recent subjects as its style, instead of the head of the diff; FIDE_AI_REPLAY replays recent commits on the local model to measure it
- Analyzer tab: File Layout review moves screens to lib/views, pure widgets to lib/widgets and plain models to lib/models, rewriting every import (Move / Move All)
- Overview: the CocoaPods check joins the Supported platforms card, shown only with iOS or macOS, instead of its own Swift packages card
- Blend backdrop: spread its color spots across wide, short previews and images, each cell after the first shuffling and moving them so no pattern repeats
- Previews by code alone: Generate Previews builds the project's and packages' classes by following imports, no AI fallback; project localizations for previews without their own; no debug banner; button labels are short action names (rule in AGENTS.md)
- Left panel: Explorer is the first tab; dot files dimmed like hidden folders, keeping their Git colors
- Code completion and live errors from the Dart language server: completions, hover docs, parameter hints and diagnostics of the code as typed, one dart language-server per project, the open file's diagnostics merged with fCheck's findings, popups styled as menus with outline icons
- Project header and quality card: one ProjectHeader and ProjectQualityCard for the overview and the Info tab, large at two cards' width and compact in a side panel; side panel sections one larger gap apart

## 1.4.5 - 2026-11-21

- Title bar: light the quality bulb only for a score below 100% or a warning or error, not for information such as large files
- Project Overview: draw transparent over the workspace gradient, its cards floating there as the settings do; the island stays opaque only for an analysis failure, whose error color reads only on the surface

## 1.4.4 - 2026-11-21

- Localization panel: list the project's locales as the Status card does, add one from a language menu (then offer Translate with AI) or remove one (not the template nor a regional locale's fallback, deleting gen-l10n's leftover file); every key shows a row per locale, the template's first: its value, what fCheck finds missing with its Translate button, or the template's text the app shows where the key is intentionally the same, with the key's description saying why; the Status card counts fCheck's findings; the New Project wizard picks its languages with the same badges and creates only the ones chosen; Translate with AI reads a reply echoing the request's {key, text} items, which qwen3-coder sends for most short batches
- Localization panel: list the project's locales as the Status card does, add one from a language menu (then offer to translate it with the local model) or remove one (not the template nor a regional locale's fallback, deleting gen-l10n's leftover file); key entries label every value by its real locale; the New Project wizard picks its languages with the same badges and creates only the ones chosen; Translate with AI reads a reply echoing the request's {key, text} items, which qwen3-coder sends for most short batches and was dropped as "no reply"
- Localization panel: list the project's locales as the Status card does, add one from a language menu (then offer to translate it with the local model) or remove one (not the template nor a regional locale's fallback, deleting gen-l10n's leftover file); key entries label every value by its real locale; the New Project wizard picks its languages with the same badges and creates only the ones chosen
- flutter_svg: 2.5.0
- Localization panel: list the project's locales as the Status card does, add one from a language menu (then offer to translate it with the local model) or remove one (not the template nor a regional locale's fallback, deleting gen-l10n's leftover file); the New Project wizard picks its languages with the same badges and creates only the ones chosen
- Run Debug: Hot Reload and Hot Restart on a line under Stop while the app runs, so a live action no longer overflows a side panel of the default width
- Localization: detect and wire the app widget wherever lib builds it (MaterialApp/CupertinoApp/WidgetsApp, .router too), not only in main.dart; Wire the app adds just the missing arguments and the import only when used, honors nullable-getter, and looks the title up only when the ARB files have appTitle
- View as Markdown: editor toolbar toggle shows every Markdown file rendered or as text, saved across launches; going to a line shows that file's text; relative images load and file links open in the editor; .markdown files open as Markdown
- Remove CocoaPods: give launched processes a UTF-8 LANG when FIDE, opened from Finder, inherits no locale, so pod no longer fails with Encoding::CompatibilityError

## 1.4.3 - 2026-11-20

- DRY: one openPlace for search matches, callers, callees and Go to Definition (caret on the name), one name resolution for callers, callees, rename and Go to Definition, so writes (=, +=, ++) count as uses and get renamed, and explicit setters as callees
- Go to Definition: ⌘-click a name (Ctrl-click off macOS) or press F12 to jump to where the project declares it, resolved by the Dart analyzer with unsaved edits included; Edit menu item, shared overlay helper in the reference worker
- README: install steps per OS, the macOS build now signed and notarized

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
