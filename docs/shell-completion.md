# Shell Completion

Tab completion is available for **bash**, **zsh**, and **fish** shells to make working with k8s-local commands easier.

## Installation

### Bash

#### For Current Session

```bash
source completions/k8s-local-completion.bash
```

#### For Permanent Installation

Add to your `~/.bashrc` or `~/.bash_profile`:

```bash
source /path/to/createlocalk8s/completions/k8s-local-completion.bash
```

Or copy to a system location:

```bash
# Linux
sudo cp completions/k8s-local-completion.bash /etc/bash_completion.d/k8s-local

# macOS (with Homebrew bash-completion)
cp completions/k8s-local-completion.bash $(brew --prefix)/etc/bash_completion.d/k8s-local
```

### Zsh

#### For Current Session

```zsh
source completions/k8s-local-completion.zsh
```

#### For Permanent Installation

Add to your `~/.zshrc`:

```zsh
# Load k8s-local completion
source /path/to/createlocalk8s/completions/k8s-local-completion.zsh
```

Or copy to zsh completion directory:

```zsh
# User completions
mkdir -p ~/.zsh/completions
cp completions/k8s-local-completion.zsh ~/.zsh/completions/_k8s-local
# Add to ~/.zshrc if not already present:
fpath=(~/.zsh/completions $fpath)
autoload -Uz compinit && compinit
```

### Fish

#### For Permanent Installation

Fish completions are automatically loaded from specific directories. Copy the completion file:

```fish
# User completions
mkdir -p ~/.config/fish/completions
cp completions/k8s-local-completion.fish ~/.config/fish/completions/

# System-wide (requires sudo)
sudo cp completions/k8s-local-completion.fish /usr/share/fish/vendor_completions.d/
```

Restart your fish shell or run:

```fish
source ~/.config/fish/completions/k8s-local-completion.fish
```

## What Gets Completed

The completion script provides tab completion for:

-   **Main commands**: `create`, `delete`, `list`, `info`, `config`, `start`, `stop`, `help`, `helm`, `apps`, `install`
-   **Helm components**: All available Helm packages (argocd, valkey, nats, metallb, etc.)
-   **ArgoCD apps**: All available ArgoCD applications (nyancat, prometheus, mongodb, etc.)
-   **Flags**: `--dry-run`

## Examples

All shells support the same completion features:

```bash
# Tab after typing partial command
./kl.sh cre<TAB>        # Completes to: ./kl.sh create

# Tab to see available helm commands
./kl.sh helm <TAB>      # Shows: list

# Tab to see what you can install
./kl.sh install <TAB>   # Shows: helm apps

# Tab to see available Helm components (with descriptions!)
./kl.sh install helm <TAB>
# Shows: argocd cert-manager cnpg crossplane falco openbao ...
# Zsh/Fish also show descriptions like "ArgoCD GitOps controller"

# Tab to see available ArgoCD apps
./kl.sh install apps <TAB>
# Shows: nyancat prometheus cert-manager cnpg-cluster crossplane ...

# Tab to add --dry-run flag
./kl.sh install helm valkey <TAB>  # Shows: --dry-run
```

## Features by Shell

| Feature                  | Bash | Zsh | Fish |
| ------------------------ | ---- | --- | ---- |
| Command completion       | ✅   | ✅  | ✅   |
| Subcommand completion    | ✅   | ✅  | ✅   |
| Helm/App name completion | ✅   | ✅  | ✅   |
| Flag completion          | ✅   | ✅  | ✅   |
| Descriptions             | ❌   | ✅  | ✅   |
| Fuzzy matching           | ❌   | ⚙️  | ✅   |

**Note**: Zsh and Fish provide richer completions with descriptions for each item. Fish also includes built-in fuzzy matching.

## Supported Shells

-   **Bash** 3.2+ (macOS, Linux, Windows Git Bash, WSL)
-   **Zsh** 5.0+ (macOS default since Catalina, Linux)
-   **Fish** 3.0+ (available on macOS, Linux)

## Troubleshooting

### Bash: Completion not working

Ensure `bash-completion` is installed:

```bash
# macOS
brew install bash-completion@2

# Ubuntu/Debian
sudo apt install bash-completion

# RHEL/Fedora
sudo dnf install bash-completion
```

### Zsh: Completion not working

Make sure `compinit` is loaded in your `~/.zshrc`:

```zsh
autoload -Uz compinit && compinit
```

### Fish: Completion not showing descriptions

This is normal behavior when viewing completions. Descriptions appear in the completion menu as you type.

### All Shells: Changes not appearing

After modifying completion files, reload them:

```bash
# Bash
source ~/.bashrc

# Zsh
source ~/.zshrc
# or run: compinit

# Fish
source ~/.config/fish/completions/k8s-local-completion.fish
```
