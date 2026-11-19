# Rules

- no magic numbers
- document all public classes, methods, functions
- fcheck --strict must score 100%
- always apply DRY: before writing new code, look for an existing widget, helper or constant to reuse; extract shared code instead of copying it
  - DRY covers widget configuration too: the same Flutter widget (`TabBar`, bordered `Container`, `TabBarView`, …) set up the same way in more than one file belongs in one shared widget under `lib/widgets/`
  - when reviewing for DRY, compare across files and folders, not just within one file or diff: list every place a widget is built and compare the calls
  - UI elements that should look alike but render differently are a sign of duplicated code that has drifted
  - DRY aims at consistent code and consistent rendering: when UI code is almost the same and differs only by a few attributes (color, radius, padding, icon size, divider color, …), remove the differences rather than adding parameters to keep them
  - keep the base building blocks simple and few; avoid snowflake UI elements and one-off variants
  - DRY covers features too: list every user-facing action (button, menu item, command) across all panels and compare what each one does, not only its code; two actions doing the same job under different names, widgets or services are duplicates — keep one
- one visible progress indicator per task: a panel with a `RefreshButton` shows its work as the ring around that button, whoever started it; other panel work shows as a `BusyBar` (thin horizontal bar atop its content, `LoadingIndicator` while nothing is shown yet); a spinner only on the button that started the task, the others just disabled; besides that, every side panel tab whose work outlasts its panel rings its tab icon while that work runs (`PanelTabSpec.busy`), so it shows from the other tabs: AI (chat replies and tasks, Ollama setup), Preview, Analyzer, Info, Run, Test
  - the tab ring wins: it shows whether its tab is selected or not, so work a tab rings for draws nothing else that spins in its panel: no `BusyBar`, no `LoadingIndicator` bar (a loading message shows alone, as `EmptyState`), no spinner, and the panel's `RefreshButton` is only disabled meanwhile, without its ring
  - the ring must never start the work it shows: read a source that works once created (an analysis, a scan) through `followBusy`
  - work kept in a widget's own state or an autoDispose provider ends with its panel, so it can't ring its tab; move it into a kept provider first
- the shared UI blocks: `PanelHeader` atop a side panel, `RefreshButton` to run a check again (end of the header), `OutlinedSurface` for any box, `SectionTitle` style for section headings, `LocationRow` for a place in the code, `TreeBranch` for tree levels, `ChoiceButtons` for one-of-N picks, `BulletList` for bulleted lines, `OutputPanel` for any console output (its header always offers Copy, Wrap and Clear; Clear drops the text at its source, so the console hides until there is output again), `TaskButton` for any task one click starts (Build, Run, Test, AI Send, AI commit message, `RefreshButton`): while it runs a ring spins around it and a red Stop replaces it when the task can be stopped, its disabled icon when not — never a bare spinner or a Stop without the ring; `TaskRing` is that ring, shared with the busy tab icons
- every text style lives in `AppTextStyle` (`lib/constants/constants.app_text_style.dart`), built on the `AppFontSize` scale; never write `TextStyle(...)`, `textTheme.*`, `fontSize:`, `fontWeight:` or line heights elsewhere — pick a style there and only add a state color with `copyWith(color: …)`; a missing style is added to that file
- every color must read at WCAG 2 AA in both themes: text 4.5:1 (`AppTheme.minTextContrast`), icons 3:1 (`AppTheme.minGlyphContrast`); `test/color_contrast_test.dart` checks it, so add each new pairing there
  - text and glyphs on a fill (badge, message, filled button) take `AppTheme.onFill(fill)`; status colors drawn straight on a surface take `readableIn` / `AppTheme.readable`
  - dim text with `onSurfaceVariant`, never with alpha on `onSurface` or a status color: translucent text falls below AA
- never use the floppy disk icon (`Icons.save*`) for Save, Commit, Apply or Persist actions: use `Icons.download`, as the editor's Save does (Apple's `square.and.arrow.down`), or a plain text label as Apple's UX does
- `fcheck --fix` can reformat unrelated files; revert changes it makes outside the task
- fCheck (package `fcheck`, repo `../fcheck`) is the brain for analyzing Flutter/Dart projects; FIDE consumes its public API (`package:fcheck/fcheck.dart`) and never reimplements analysis
  - never change fCheck's source (code, tests, docs) without the user's authorization: the user reviews every fCheck change
  - when FIDE needs a new finding or metric, propose the fCheck change to the user first (it has its own users, so keep it general); only after they authorize it, add it to fCheck and use it from FIDE
  - never import `package:fcheck/src/...`; export what FIDE needs from fCheck instead
  - `AnalyzeFolder.analyze()` is synchronous: run it with `Isolate.run`
- AI panel: when the user asks to fix or change code, the AI edits the project files (through `CodeEditAgent`); it never replies with code for the user to paste
  - code decides whether a prompt asks for a change (`PromptIntent`), not the model: any other prompt is answered by an agent whose tools only read, as a local model given editing tools edits files even for "2+2="
  - the agent is offered FIDE's whole-project quick fixes only when the request names their subject (`QuickFix.topics`), never all of them
- prefer deterministic code refactorings (quick fixes) over sending work to the AI: the local model is too slow for mechanical changes; leave the AI only what code cannot decide or rewrite
- AI is private, local and fast: it runs only on the local Ollama model, offline, and the code never leaves the computer; no cloud or remote AI provider (they were tried and removed as too complex to set up)
- never regress the local AI's speed or judgment; every AI change keeps these, and re-measures against a real Ollama model when it touches the agent, its prompts or tools:
  - keep the model's context small, as it slows down sharply as it fills (on an M4 Max, qwen3-coder reads 1,200 tokens/s near the start, 300 at 24k; writes 129 tokens/s, 25 at 28k): the agent stays within `ChatModel.contextBudget`, dropping the oldest tool outputs first, never letting Ollama overflow and cut the conversation
  - tools return bounded output: `list_files` capped, files read in parts, `search` before reading, history capped
  - tools answer with what the model would otherwise read the file again for: an edit answers with the lines it changed, `check_build` quotes the line of code under each error, a replace it can't make shows where the text (or its first line) is; `replace_in_file` takes `replace_all` for renames; every step costs a round trip
  - the agent checks its work with `dart analyze` (seconds), building only to fix a failed build (a release build takes minutes)
  - stream replies, warm the model up when the prompt takes focus, and retry Ollama's malformed tool calls with a request that says what went wrong: the same request writes the same broken call
  - a call the model repeats with nothing changed in between gets its earlier result and a note instead of running again, and the agent stops after `AppMetric.aiMaxRepeatedCalls` of them: a local model can loop on one, such as `check_build`
  - every agent tool takes at least one required parameter: qwen3-coder can leave a call with none unclosed (`<function=…>` without `</function>`), which Ollama fails as "XML syntax error … unexpected EOF"
  - the routing above: a question gets read-only tools, quick fixes only when named
  - reference timings to stay at or under: "2+2=" answered in one step without tools, in ~4 s; a question needing one file read ~5 s; a rename in one file 6 steps, ~8 s; a multi-file Fix Build of 10 errors ~20 steps, ~40 s; the step cap (`AppMetric.aiMaxToolRounds`) stays far above what a task takes

# Workflow

- after making changes, always offer a one-line git commit message covering all pending changed files; don't commit unless asked
- when given a new rule or standing instruction, add it to this file, not only to private agent memory
