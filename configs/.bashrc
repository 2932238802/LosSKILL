# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract from the user: build-up
# to select.  See /etc/bash_completion.d/git-prompt if you have it.
# If you want a colored prompt, turn on some of the following
# options, and see /etc/bash_completion for the full set of prompt variables.
if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='grep --color=auto'
fi

# some more ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# My custom aliases
alias gs='git status'
alias gp='git pull'
alias gpush='git push'
alias gc='git commit'
alias gco='git checkout'
alias gd='git diff'
alias vim='nvim'
alias code='code'
alias cls='clear'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'


# =================================================================
#               历史：前缀搜索 + 可视匹配列表（LosSKILL）
# =================================================================
HISTSIZE=100000
HISTFILESIZE=200000
HISTCONTROL=ignoredups:ignorespace
shopt -s histappend

# 输入前缀后按 ↑ / ↓：只翻「以当前输入开头」的历史
bind '"\e[A": history-search-backward'
bind '"\e[B": history-search-forward'

# Ctrl+X Ctrl+H：把以当前输入开头的最近 10 条历史打印成 <History(N)> 列表
__los_hist_list() {
    local pat="${READLINE_LINE:-}" count=10 body n
    body=$(history | sed -E 's/^ *[0-9]+ +//' | grep -F -- "$pat" | awk '!seen[$0]++' | tail -n "$count")
    if [ -z "$body" ]; then
        printf '\n\033[2m<History(0)> no match for "%s"\033[0m\n' "$pat"
        return
    fi
    n=$(printf '%s\n' "$body" | wc -l | tr -d ' ')
    printf '\n\033[1;36m<History(%s)>\033[0m\n' "$n"
    printf '%s\n' "$body" | sed 's/^/  > /'
}
bind -x '"\C-x\C-h": __los_hist_list'

# Ctrl+R：fzf 弹层模糊搜索历史；没有 fzf 就用 bash 自带的增量搜索
if command -v fzf >/dev/null 2>&1; then
    __los_fzf_history() {
        local sel
        sel=$(history | sed -E 's/^ *[0-9]+ +//' | awk '!seen[$0]++' | tac |
              fzf --height=40% --reverse --border --info=inline \
                  --prompt='history> ' --header='<History> Enter 选中，Esc 取消') || return 0
        READLINE_LINE="$sel"
        READLINE_POINT=${#READLINE_LINE}
    }
    bind -x '"\C-r": __los_fzf_history'
else
    bind '"\C-r": reverse-search-history'
fi
