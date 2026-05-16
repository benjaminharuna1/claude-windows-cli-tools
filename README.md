# Claude CLI Manager

A simple Bash-based CLI manager for installing, configuring, and controlling the Claude CLI service.

## Overview

`claude-manager.sh` is a menu-driven script that helps you:

- install Claude CLI via `npm`
- configure provider settings, API keys, and model selection
- create and manage a `systemd --user` service for Claude CLI
- enable or disable autostart
- start, stop, and check Claude service status
- run Claude manually with the saved configuration

Supported providers:

- Anthropic API
- Ollama
- LM Studio
- OpenRouter
- Custom OpenAI-compatible API endpoints

## Requirements

- Bash shell
- Node.js installed and available in `PATH`
- `npm`
- `systemd --user` available on your environment
- `claude` CLI executable should be installed or installable via `npm install -g @anthropic-ai/claude-code`

For Ollama support, install Ollama separately.
For LM Studio support, run an LM Studio instance locally.

> Note: This script is written for Linux-like environments with `systemd` support. If you are on Windows, use WSL or another compatible shell environment.

## Installation

1. Clone or download this repository.
2. Make the script executable:

```bash
chmod +x claude-manager.sh
```

3. Run the script:

```bash
./claude-manager.sh
```

## Usage

The script launches a text menu with the following options:

1. Install Claude CLI
2. Configure Claude
3. Start Claude Service
4. Stop Claude Service
5. Enable Autostart
6. Disable Autostart
7. Service Status
8. Run Claude Manually
9. Exit

### Configure Claude

When configuring, choose one of the supported providers and enter the required values:

- Anthropic: API URL, API key, and model name
- Ollama: auto-detect running model or select from installed models
- LM Studio: local LM Studio URL and model name
- OpenRouter: API URL, API key, and model name
- Custom: custom base URL, API key, and model name

Configuration is saved to `~/.claude-cli-manager/config.env`.

### Service management

The script creates a user-level service file at:

- `~/.config/systemd/user/claude-cli.service`

It sets environment variables from the saved configuration and uses `claude` as the service command.

## Notes

- The script stores configuration in `~/.claude-cli-manager/config.env`.
- If running on a system without `systemd --user`, the service-related options will not work.
- Use option 8 to launch `claude` manually with the current saved configuration.

## License

This project is licensed under a personal-use license. It is free to use for
personal projects, but not for sale or commercial use without prior permission.
For commercial or for-sale use, contact the developer. See `LICENSE` for full
details.
