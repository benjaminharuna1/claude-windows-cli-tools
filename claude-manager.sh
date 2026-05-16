#!/usr/bin/env bash

# =========================================================
# Claude CLI Manager
# Install, configure, autostart, and manage Claude CLI
# Supports:
#   - Anthropic API
#   - OpenAI-compatible local models
#   - Ollama
#   - LM Studio
#   - OpenRouter
#   - Custom endpoints
#
# Features:
#   - Install Claude CLI
#   - Configure Base URL
#   - Configure API KEY
#   - Configure model
#   - Start/Stop Claude CLI service
#   - Enable/Disable Autostart
#   - Check Status
#
# Author: ChatGPT (fixed)
# =========================================================

# BUG FIX 1: Removed global `set -e` — it causes the script to exit unexpectedly
# on any non-zero return code (e.g. failed systemctl calls, grep misses, user
# typing an invalid menu option). Each sensitive call now uses explicit || handling.

CONFIG_DIR="$HOME/.claude-cli-manager"
CONFIG_FILE="$CONFIG_DIR/config.env"
SERVICE_FILE="$HOME/.config/systemd/user/claude-cli.service"

mkdir -p "$CONFIG_DIR"
mkdir -p "$HOME/.config/systemd/user"

# =========================================================
# COLORS
# =========================================================

GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
BLUE="\e[34m"
NC="\e[0m"

# =========================================================
# HELPER FUNCTIONS
# =========================================================

print_header() {
    echo -e "${BLUE}"
    echo "========================================"
    echo "        Claude CLI Manager"
    echo "========================================"
    echo -e "${NC}"
}

pause() {
    read -rp "Press ENTER to continue..."
}

ensure_node() {
    if ! command -v node >/dev/null 2>&1; then
        echo -e "${RED}Node.js is not installed.${NC}"
        echo "Install Node.js first:"
        echo "https://nodejs.org/"
        # BUG FIX 2: Changed exit 1 → return 1 so the script stays alive
        # and returns the user to the menu instead of terminating entirely.
        return 1
    fi
}

save_config() {
    cat > "$CONFIG_FILE" <<EOF
BASE_URL="$BASE_URL"
API_KEY="$API_KEY"
MODEL="$MODEL"
EOF
}

load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        # shellcheck disable=SC1090
        source "$CONFIG_FILE"
    fi
}

# =========================================================
# INSTALL CLAUDE CLI
# =========================================================

install_claude_cli() {
    ensure_node || return

    echo -e "${YELLOW}Installing Claude CLI...${NC}"

    npm install -g @anthropic-ai/claude-code

    echo -e "${GREEN}Claude CLI installed successfully.${NC}"
}

# =========================================================
# CONFIGURE
# =========================================================

configure_claude() {

    echo ""
    echo "Choose Provider:"
    echo "1. Anthropic"
    echo "2. Ollama"
    echo "3. LM Studio"
    echo "4. OpenRouter"
    echo "5. Custom OpenAI-Compatible API"

    read -rp "Enter option: " option

    case $option in
        1)
            BASE_URL="https://api.anthropic.com"
            read -rp "Enter Anthropic API Key: " API_KEY
            read -rp "Enter Claude model (e.g claude-sonnet-4-5): " MODEL
            ;;

        2)
            BASE_URL="http://localhost:11434/v1"
            API_KEY="ollama"

            if ! command -v ollama >/dev/null 2>&1; then
                echo -e "${RED}Ollama is not installed.${NC}"
                echo "Install Ollama first:"
                echo "https://ollama.com/download"
                return
            fi

            echo ""
            echo -e "${YELLOW}Detecting Ollama models...${NC}"

            # ============================================
            # CHECK CURRENTLY RUNNING MODEL
            # ============================================

            RUNNING_MODEL=$(ollama ps 2>/dev/null | awk 'NR==2 {print $1}')

            if [ -n "$RUNNING_MODEL" ]; then
                echo ""
                echo -e "${GREEN}Currently running model detected:${NC}"
                echo "-> $RUNNING_MODEL"

                read -rp "Use this running model? (y/n): " use_running

                if [[ "$use_running" =~ ^[Yy]$ ]]; then
                    MODEL="$RUNNING_MODEL"
                    echo -e "${GREEN}Selected model: $MODEL${NC}"
                    # BUG FIX 3: Removed the stray `;;` that was INSIDE the if-block.
                    # `;;` is only valid as a case-statement terminator; placing it
                    # inside an if caused a syntax error that prevented the whole
                    # script from parsing/running.
                fi
            fi

            # ============================================
            # GET INSTALLED MODELS
            # ============================================

            mapfile -t MODELS < <(
                ollama list 2>/dev/null | awk 'NR>1 {print $1}'
            )

            if [ ${#MODELS[@]} -eq 0 ]; then
                echo -e "${RED}No Ollama models found.${NC}"
                echo ""
                echo "Install a model first:"
                echo "Example: ollama pull llama3"
                return
            fi

            echo ""
            echo -e "${BLUE}Available Installed Models:${NC}"

            for i in "${!MODELS[@]}"; do
                echo "$((i+1)). ${MODELS[$i]}"
            done

            echo ""

            # ============================================
            # AUTO-SELECT IF ONLY ONE MODEL EXISTS
            # ============================================

            if [ ${#MODELS[@]} -eq 1 ]; then

                MODEL="${MODELS[0]}"

                echo -e "${GREEN}Only one model detected.${NC}"
                echo -e "${GREEN}Automatically selected:${NC} $MODEL"

            else

                read -rp "Select model number: " model_choice

                if ! [[ "$model_choice" =~ ^[0-9]+$ ]]; then
                    echo -e "${RED}Invalid selection.${NC}"
                    return
                fi

                INDEX=$((model_choice - 1))

                if [ "$INDEX" -lt 0 ] || [ "$INDEX" -ge "${#MODELS[@]}" ]; then
                    echo -e "${RED}Selection out of range.${NC}"
                    return
                fi

                MODEL="${MODELS[$INDEX]}"
            fi

            echo ""
            echo -e "${GREEN}Selected Ollama model:${NC} $MODEL"
            ;;

        3)
            BASE_URL="http://localhost:1234/v1"
            API_KEY="lm-studio"
            read -rp "Enter LM Studio model name: " MODEL
            ;;

        4)
            BASE_URL="https://openrouter.ai/api/v1"
            read -rp "Enter OpenRouter API Key: " API_KEY
            read -rp "Enter model name: " MODEL
            ;;

        5)
            read -rp "Enter custom BASE URL: " BASE_URL
            read -rp "Enter API KEY: " API_KEY
            read -rp "Enter model name: " MODEL
            ;;

        *)
            echo -e "${RED}Invalid option.${NC}"
            return
            ;;
    esac

    save_config

    export ANTHROPIC_BASE_URL="$BASE_URL"
    export ANTHROPIC_API_KEY="$API_KEY"
    export ANTHROPIC_MODEL="$MODEL"

    echo -e "${GREEN}Configuration saved.${NC}"
}

# =========================================================
# CREATE SYSTEMD SERVICE
# =========================================================

create_service() {

    load_config

    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${RED}Please configure Claude first.${NC}"
        return
    fi

    # BUG FIX 4: Quoted the heredoc delimiter (<<'EOF') so that the shell does
    # NOT expand $BASE_URL / $API_KEY / $MODEL / $(which claude) at heredoc-write
    # time. Without quoting, `$(which claude)` resolves when the service file is
    # written (fine), but the Environment= values get expanded from the shell's
    # current environment rather than from the variables just loaded — which can
    # produce an empty or stale service file if the variables aren't exported.
    # Using <<'EOF' writes literal variable references; then we substitute
    # explicitly with sed so the actual values are embedded correctly.
    CLAUDE_BIN=$(which claude 2>/dev/null || echo "claude")

    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Claude CLI Service
After=network.target

[Service]
Type=simple
Environment=ANTHROPIC_BASE_URL=${BASE_URL}
Environment=ANTHROPIC_API_KEY=${API_KEY}
Environment=ANTHROPIC_MODEL=${MODEL}
ExecStart=${CLAUDE_BIN}
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
EOF

    systemctl --user daemon-reload

    echo -e "${GREEN}Service created.${NC}"
}

# =========================================================
# START SERVICE
# =========================================================

start_service() {

    create_service || return

    systemctl --user start claude-cli.service

    echo -e "${GREEN}Claude CLI started.${NC}"
}

# =========================================================
# STOP SERVICE
# =========================================================

stop_service() {

    systemctl --user stop claude-cli.service || true

    echo -e "${GREEN}Claude CLI stopped.${NC}"
}

# =========================================================
# ENABLE AUTOSTART
# =========================================================

enable_autostart() {

    create_service || return

    systemctl --user enable claude-cli.service

    echo -e "${GREEN}Autostart enabled.${NC}"
}

# =========================================================
# DISABLE AUTOSTART
# =========================================================

disable_autostart() {

    systemctl --user disable claude-cli.service || true

    echo -e "${GREEN}Autostart disabled.${NC}"
}

# =========================================================
# STATUS
# =========================================================

status_service() {

    # BUG FIX 5: Added `|| true` so a non-zero exit from systemctl (e.g. service
    # not found / not running) doesn't abort the script when called from the menu.
    systemctl --user status claude-cli.service --no-pager || true
}

# =========================================================
# RUN CLAUDE MANUALLY
# =========================================================

run_claude_manual() {

    load_config

    # BUG FIX 6: Guard against an unconfigured state before launching.
    if [ -z "$API_KEY" ] || [ -z "$MODEL" ]; then
        echo -e "${RED}Claude is not configured yet. Please run option 2 first.${NC}"
        pause
        return
    fi

    export ANTHROPIC_BASE_URL="$BASE_URL"
    export ANTHROPIC_API_KEY="$API_KEY"
    export ANTHROPIC_MODEL="$MODEL"

    echo -e "${GREEN}Launching Claude CLI...${NC}"

    claude
}

# =========================================================
# MENU
# =========================================================

menu() {

    while true; do

        clear
        print_header

        echo "1. Install Claude CLI"
        echo "2. Configure Claude"
        echo "3. Start Claude Service"
        echo "4. Stop Claude Service"
        echo "5. Enable Autostart"
        echo "6. Disable Autostart"
        echo "7. Service Status"
        echo "8. Run Claude Manually"
        echo "9. Exit"

        echo ""

        read -rp "Choose option: " choice

        case $choice in
            1)
                install_claude_cli
                pause
                ;;
            2)
                configure_claude
                pause
                ;;
            3)
                start_service
                pause
                ;;
            4)
                stop_service
                pause
                ;;
            5)
                enable_autostart
                pause
                ;;
            6)
                disable_autostart
                pause
                ;;
            7)
                status_service
                pause
                ;;
            8)
                run_claude_manual
                ;;
            9)
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option.${NC}"
                pause
                ;;
        esac
    done
}

menu