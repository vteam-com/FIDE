# Changelog

What changed in each FIDE release, newest first. `tool/release.sh` adds each release's entry: one line per commit since the release before.

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
