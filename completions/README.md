# Shell Completions

This directory contains tab completion scripts for **bash**, **zsh**, and **fish** shells.

## Quick Installation

Run the automated installer:

```bash
./install-completion.sh
```

This will detect your shell and install the appropriate completion automatically.

## Manual Installation

### Bash

```bash
echo 'source ~/dev/github/roger/createlocalk8s/completions/k8s-local-completion.bash' >> ~/.bashrc
source ~/.bashrc
```

### Zsh

```bash
echo 'source ~/dev/github/roger/createlocalk8s/completions/k8s-local-completion.zsh' >> ~/.zshrc
source ~/.zshrc
```

### Fish

```bash
mkdir -p ~/.config/fish/completions
cp k8s-local-completion.fish ~/.config/fish/completions/
```

## Files

-   **k8s-local-completion.bash** - Bash completion (Bash 3.2+)
-   **k8s-local-completion.zsh** - Zsh completion with descriptions (Zsh 5.0+)
-   **k8s-local-completion.fish** - Fish completion with descriptions (Fish 3.0+)
-   **install-completion.sh** - Automated installer script

## What You Get

Tab completion for:

-   ✅ Main commands: `create`, `delete`, `list`, `info`, `config`, `start`, `stop`, `help`, `helm`, `apps`, `install`
-   ✅ Helm components: `argocd`, `redis-stack`, `nats`, `metallb`, `mongodb-operator`, etc.
-   ✅ ArgoCD apps: `nyancat`, `prometheus`, `mongodb`, `cnpg-cluster`, etc.
-   ✅ Flags: `--dry-run`
-   ✅ Works with all script names: `./kl.sh`, `./k8s-local.sh`, `./create-cluster.sh`

## Documentation

See [docs/shell-completion.md](../docs/shell-completion.md) for detailed installation instructions, examples, and troubleshooting.
