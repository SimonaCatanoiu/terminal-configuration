#!/bin/bash

# This script installs bash-autosuggestions, kubectl, krew, kube-ps1, and sets up a clean bash environment.

set -euo pipefail

# Install tools for the current user, without requiring root.
export PATH="$HOME/.local/bin:${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
for dependency in curl tar git; do
    if ! command -v "$dependency" >/dev/null 2>&1; then
        echo "Required command not found: $dependency" >&2
        exit 1
    fi
done

OS="$(uname | tr '[:upper:]' '[:lower:]')"
case "$(uname -m)" in
    x86_64) ARCH=amd64 ;;
    aarch64|arm64) ARCH=arm64 ;;
    *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

work_dir="$(mktemp -d)"
trap 'rm -rf -- "$work_dir"' EXIT

if ! command -v kubectl >/dev/null 2>&1; then
    echo "Installing kubectl..."
    version="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
    curl -fsSL "https://dl.k8s.io/release/${version}/bin/${OS}/${ARCH}/kubectl" -o "$work_dir/kubectl"
    mkdir -p "$HOME/.local/bin"
    install -m 0755 "$work_dir/kubectl" "$HOME/.local/bin/kubectl"
fi

if ! command -v kubectl-krew >/dev/null 2>&1; then
    echo "Installing krew..."
    KREW="krew-${OS}_${ARCH}"
    curl -fsSL "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" -o "$work_dir/krew.tar.gz"
    tar -xzf "$work_dir/krew.tar.gz" -C "$work_dir"
    "$work_dir/$KREW" install krew
fi

if [ ! -s "$HOME/.kube-ps1.sh" ]; then
    echo "Installing kube-ps1..."
    curl -fsSL https://raw.githubusercontent.com/jonmosco/kube-ps1/master/kube-ps1.sh -o "$work_dir/kube-ps1.sh"
    install -m 0644 "$work_dir/kube-ps1.sh" "$HOME/.kube-ps1.sh"
fi

# Keep a backup before changing shell configuration.
if [ -f "$HOME/.bashrc" ]; then
    cp "$HOME/.bashrc" "$HOME/.bashrc.bak"
fi

# Update .bashrc with required configurations
echo "Configuring bash..."

if ! grep -q '^# BEGIN terminal_config$' "$HOME/.bashrc" 2>/dev/null; then
cat <<'EOL' >> "$HOME/.bashrc"
# BEGIN terminal_config

# Add krew bin to PATH
export PATH="$HOME/.local/bin:${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

# Enable bash-completion
if [ -f /usr/local/share/bash-completion/bash_completion ]; then
    . /usr/local/share/bash-completion/bash_completion
fi

# History configuration
HISTFILE=~/.bash_history
HISTSIZE=1000
SAVEHIST=1000
HISTTIMEFORMAT="%d/%m/%y %T "
HISTIGNORE="&:ls:ll:la:history:exit:clear"
PROMPT_COMMAND='history -a'
alias h="history"

#Search in history with up and down arrow keys
bind '"\e[A": history-search-backward'
bind '"\e[B": history-search-forward'
bind '"\e[C": forward-char'
bind '"\e[D": backward-char'

#TAB completion features
bind '"\t":menu-complete'
bind "set show-all-if-ambiguous on"
bind "set completion-ignore-case on"
bind "set menu-complete-display-prefix on"

# Aliases for kubectl
alias k='kubectl'
alias kg='kubectl get'
alias kd='kubectl describe'
alias kl='kubectl logs'
alias klogs='kubectl logs -f --max-log-requests=20 --all-containers=true --selector'
alias kns='kubectl config set-context --current --namespace'

# User specific aliases and functions
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# Color Linux commands
color_param="--color=auto"
alias ls="ls $color_param"
alias ll="ls -alF $color_param"
alias grep="grep $color_param"
alias egrep="egrep $color_param"

# Autocomplete settings for kubectl
if command -v kubectl >/dev/null 2>&1; then
    source <(kubectl completion bash)
    complete -o default -F __start_kubectl k
fi

# Set up kube-ps1 for Kubernetes context in prompt
if [ -f "$HOME/.kube-ps1.sh" ]; then
    source "$HOME/.kube-ps1.sh"
    PS1='$(kube_ps1) \w \$ '
fi

# Function to display current Git branch in the prompt
getBranch() {
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [[ -n "$branch" ]]; then
        echo "($branch)"
    fi
}

# Include Git branch in the prompt
export PS1="$PS1 \$(getBranch) "
# END terminal_config
EOL
fi

# Verify installation
echo "Verifying installation..."
kubectl version --client
kubectl krew version
# An executed script cannot change its parent shell.
echo 'Installation complete. Run: source ~/.bashrc'
