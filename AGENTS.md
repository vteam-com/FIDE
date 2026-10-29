# Rules

- no magic numbers
- document all public classes, methods, functions
- fcheck --strict must score 100%
- always apply DRY: before writing new code, look for an existing widget, helper or constant to reuse; extract shared code instead of copying it
  - DRY covers widget configuration too: the same Flutter widget (`TabBar`, bordered `Container`, `TabBarView`, …) set up the same way in more than one file belongs in one shared widget under `lib/widgets/`
  - when reviewing for DRY, compare across files and folders, not just within one file or diff: list every place a widget is built and compare the calls
  - UI elements that should look alike but render differently are a sign of duplicated code that has drifted
- `fcheck --fix` can reformat unrelated files; revert changes it makes outside the task

# Workflow

- after making changes, always offer a one-line git commit message covering all pending changed files; don't commit unless asked
- when given a new rule or standing instruction, add it to this file, not only to private agent memory
