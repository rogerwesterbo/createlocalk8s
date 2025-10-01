#!/usr/bin/env bash
# Quick installer for shell completions

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPLETIONS_DIR="${SCRIPT_DIR}"

detect_shell() {
    # Check parent shell from SHELL environment variable
    local parent_shell=$(basename "$SHELL")
    
    case "$parent_shell" in
        zsh)
            echo "zsh"
            ;;
        fish)
            echo "fish"
            ;;
        bash)
            echo "bash"
            ;;
        *)
            # Fallback to checking version variables (if sourced)
            if [ -n "$ZSH_VERSION" ]; then
                echo "zsh"
            elif [ -n "$FISH_VERSION" ]; then
                echo "fish"
            elif [ -n "$BASH_VERSION" ]; then
                echo "bash"
            else
                echo "unknown"
            fi
            ;;
    esac
}

install_bash_completion() {
    local rc_file="$HOME/.bashrc"
    [ -f "$HOME/.bash_profile" ] && rc_file="$HOME/.bash_profile"
    
    local source_line="source $COMPLETIONS_DIR/k8s-local-completion.bash"
    
    if grep -q "k8s-local-completion.bash" "$rc_file" 2>/dev/null; then
        echo "✓ Bash completion already installed in $rc_file"
    else
        echo "" >> "$rc_file"
        echo "# k8s-local shell completion" >> "$rc_file"
        echo "$source_line" >> "$rc_file"
        echo "✓ Added completion to $rc_file"
    fi
    
    echo ""
    echo "To activate now, run:"
    echo "  source $rc_file"
}

install_zsh_completion() {
    local rc_file="$HOME/.zshrc"
    
    local source_line="source $COMPLETIONS_DIR/k8s-local-completion.zsh"
    
    if grep -q "k8s-local-completion.zsh" "$rc_file" 2>/dev/null; then
        echo "✓ Zsh completion already installed in $rc_file"
    else
        echo "" >> "$rc_file"
        echo "# k8s-local shell completion" >> "$rc_file"
        echo "$source_line" >> "$rc_file"
        echo "✓ Added completion to $rc_file"
    fi
    
    echo ""
    echo "To activate now, run:"
    echo "  source $rc_file"
}

install_fish_completion() {
    local fish_dir="$HOME/.config/fish/completions"
    mkdir -p "$fish_dir"
    
    cp "$COMPLETIONS_DIR/k8s-local-completion.fish" "$fish_dir/"
    echo "✓ Copied completion to $fish_dir/"
    
    echo ""
    echo "To activate now, run:"
    echo "  source $fish_dir/k8s-local-completion.fish"
}

main() {
    echo "k8s-local Shell Completion Installer"
    echo "====================================="
    echo ""
    
    local shell=$(detect_shell)
    
    if [ "$shell" = "unknown" ]; then
        echo "Error: Could not detect shell type"
        echo ""
        echo "Please manually install completion for your shell:"
        echo "  Bash: source completions/k8s-local-completion.bash"
        echo "  Zsh:  source completions/k8s-local-completion.zsh"
        echo "  Fish: cp completions/k8s-local-completion.fish ~/.config/fish/completions/"
        exit 1
    fi
    
    echo "Detected shell: $shell"
    echo ""
    
    case $shell in
        bash)
            install_bash_completion
            ;;
        zsh)
            install_zsh_completion
            ;;
        fish)
            install_fish_completion
            ;;
    esac
    
    echo ""
    echo "✓ Installation complete!"
}

main "$@"
