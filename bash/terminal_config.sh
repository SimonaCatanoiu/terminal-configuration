#!/bin/bash

# This script installs bash-autosuggestions, kubectl, krew, kube-ps1, and sets up a clean bash environment.

# Backup current bashrc
cp ~/.bashrc ~/.bashrc.bak

# Function to install a package if it's not already installed
install_if_missing() {
    local package=$1
    if ! command -v "$package" &>/dev/null; then
        echo "Installing $package..."
        "$2"
    else
        echo "$package is already installed."
    fi
}

# Install kubectl if not installed
install_if_missing kubectl "curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/$(uname | tr '[:upper:]' '[:lower:]')/amd64/kubectl && chmod +x kubectl && mv kubectl /usr/local/bin"

# Install krew if not installed
if ! command -v kubectl-krew &>/dev/null; then
    echo "Installing krew manually..."
    (
        set -x
        cd "$(mktemp -d)" &&
        OS="$(uname | tr '[:upper:]' '[:lower:]')" &&
        ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&
        KREW="krew-${OS}_${ARCH}" &&
        curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&
        tar zxvf "${KREW}.tar.gz" &&
        ./"${KREW}" install krew
    )
else
    echo "krew is already installed."
fi

# Install kube-ps1 if not installed
install_if_missing kube-ps1 "curl -fsSL https://github.com/PSVant/kube-ps1/releases/latest/download/kube-ps1.sh -o ~/.kube-ps1.sh"

# Update .bashrc with required configurations
echo "Configuring bash..."

cat <<'EOL' >> ~/.bashrc

# Add krew bin to PATH
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

# Add kubectl and kube-ps1 to PATH
export PATH="$HOME/.krew/bin:$PATH"

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
bind "\e[C": forward-char
bind "\e[D": backward-char

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
source <(kubectl completion bash)

# Set up kube-ps1 for Kubernetes context in prompt
PS1='$(source ~/.kube-ps1.sh; kube_ps1) \w \$ '

# Function to display current Git branch in the prompt
getBranch() {
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [[ -n "$branch" ]]; then
        echo "($branch)"
    fi
}

# Include Git branch in the prompt
export PS1="$PS1 \$(getBranch) "
EOL

# Reload .bashrc to apply changes immediately
echo "Reloading .bashrc..."
source ~/.bashrc

# Verify installation
echo "Verifying installation..."
kubectl version --client
kubectl krew version
