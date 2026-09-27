# screenie

A tiny macOS 26 overlay for asking an AI about what's on your screen.

Press **Option–Space**, type a question, and screenie takes one screenshot of the display under your pointer, runs on-device OCR on it, and sends both with your prompt to the AI model you choose. The answer streams into a small floating glass panel above the input bar.

## Features

- One screenshot per question — never continuous capture.
- Apple Vision OCR sent alongside the image for better accuracy.
- OpenRouter (default) or OpenAI API, with an OpenRouter model picker right in the input bar.
- Markdown and LaTeX math rendering in answers.
- Local conversation history with AI-generated topic titles.
- `/task` or **Option–Command–Space** opens a task manager; dated tasks sync to Apple Calendar.
- Lives in the menu bar and launches at login.

## Requirements

- macOS 26 or later on an Apple Silicon Mac
- An [OpenRouter](https://openrouter.ai/keys) or [OpenAI](https://platform.openai.com/api-keys) API key

## Install

1. Download the latest `screenie-*-macos.zip` from [Releases](https://github.com/NicolasDangg/screenie/releases/latest).
2. Unzip it and drag **screenie.app** into your **Applications** folder.
3. Open it. The app isn't notarized, so macOS will block the first launch. Either:
   - right-click **screenie.app** → **Open** → **Open**, or
   - go to **System Settings → Privacy & Security** and click **Open Anyway**, or
   - run this in Terminal:

     ```bash
     xattr -dr com.apple.quarantine /Applications/screenie.app
     ```

4. screenie appears as an icon in the menu bar (there is no Dock icon).

## Set up

1. **Grant Screen Recording.** Open **Settings…** from the menu-bar icon and use the permission button, or go to **System Settings → Privacy & Security → Screen & System Audio Recording** and enable screenie. Quit and reopen screenie afterwards so the permission takes effect.
2. **Add your API key.** In **Settings…**, pick a provider, paste your key, and click **Save API Key**.
3. **Pick a model.** With OpenRouter, click the model name in the overlay's input bar to search and choose a model, or type a model ID in **Settings…**.

## Use

| Action | Shortcut |
| --- | --- |
| Show / hide the overlay | Option–Space |
| Open the task manager | Option–Command–Space, or type `/task` |
| Close the overlay | Escape |

Drag the panel by its background to move it; screenie remembers where you left it. Past conversations are under **History** in the menu-bar menu.

## Privacy

- Screenshots and OCR text are sent to your chosen API provider with each question, but are **never saved** to disk.
- Prompts, answers, titles, and tasks are stored locally in `~/Library/Application Support/ScreenSage/`.
- Your API key is stored in the app's local preferences (`UserDefaults`), not the Keychain.

## Build from source

Requires Xcode 26.

```bash
git clone https://github.com/NicolasDangg/screenie.git
cd screenie
./scripts/install.sh
```

`install.sh` builds a Release version, replaces `/Applications/screenie.app`, and relaunches it. To build locally you'll need to set your own signing team in the Xcode project.

Run the tests:

```bash
xcodebuild test -project ScreenSage.xcodeproj -scheme ScreenSage -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```

## Uninstall

Quit screenie from the menu bar, then delete `/Applications/screenie.app`. To remove your history and tasks too, delete `~/Library/Application Support/ScreenSage/`.
