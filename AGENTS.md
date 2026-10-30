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
- `fcheck --fix` can reformat unrelated files; revert changes it makes outside the task
- fCheck (package `fcheck`, repo `../fcheck`) is the brain for analyzing Flutter/Dart projects; FIDE consumes its public API (`package:fcheck/fcheck.dart`) and never reimplements analysis
  - when FIDE needs a new finding or metric, add it to fCheck first (it has its own users, so keep it general), then use it from FIDE
  - never import `package:fcheck/src/...`; export what FIDE needs from fCheck instead
  - `AnalyzeFolder.analyze()` is synchronous: run it with `Isolate.run`
- AI panel: when the user asks to fix or change code, the AI edits the project files (through `CodeEditAgent`); it never replies with code for the user to paste

# Workflow

- after making changes, always offer a one-line git commit message covering all pending changed files; don't commit unless asked
- when given a new rule or standing instruction, add it to this file, not only to private agent memory
