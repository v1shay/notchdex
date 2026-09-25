# NotchDex

A lightweight macOS notch terminal that launches the Codex CLI in a real PTY.

## Features

- A smoothly animated panel that grows out of the physical MacBook notch.
- Four panel sizes and four independent, color-coded Codex terminal sessions.
- A subtle animated glass edge and border beam.
- Configurable terminal colors, transparency, and opacity from the menu bar.
- Global keyboard gestures and built-in voice dictation.

## Gestures

- Hold either Shift key for 2 seconds to open.
- Double-tap Shift to close.
- While the terminal is active, hold X for 0.3 seconds to dictate. Release X to insert the transcript. A quick X press still types `x`.

## Build

```sh
./scripts/build-app.sh
open "outputs/Notch Codex.app"
```

The first launch requests Accessibility access for global Shift/X gestures, plus microphone and speech-recognition permission for dictation. If Codex is not signed in, its normal browser login runs inside the terminal flow and the CLI reuses its cached credentials on future launches.

For Keychain-backed Codex credentials, set this in `~/.codex/config.toml`:

```toml
cli_auth_credentials_store = "keyring"
```
