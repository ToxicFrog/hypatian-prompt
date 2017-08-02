#!/bin/zsh

# Hypatian ZSH Prompt Theme
# Katherine Prevost <kat@hypatian.org>

# Requires zsh 5.3+

# This work is licensed under a Creative Commons Attribution 4.0
# International License.
# CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/)

# Inspired by ideas from:
#   slimline (https://github.com/mgee/slimline)
#   liquidprompt (https://github.com/nojhan/liquidprompt)

# Example:
#
# username@hostname ~/src/repository •               ☿ default !? ⇣⇡ √
#
# This uses two separate asynchronous processes to fetch faster and
# slower information from subprocesses. The fast one gets info about
# your VC working directory. The slow one gets info about its
# relationship to remote repositories (if possible).
#
# A number of features can be enabled and disabled, and the symbols
# and colors used can be configured by setting entries in three
# associative arrays, described below.

## Configuration Options ###############################################

# Set after sourcing this using:
#   _hp_conf[enable_async] = 0
# and so on

typeset -A _hp_conf
_hp_conf=(
  enable_async     1
  enable_async_x   1
  enable_env       1
  enable_env_proxy 1
  enable_pwd       1
  enable_priv      1
  enable_priv_sudo 1
  enable_priv_krb  1
  enable_vc_git    1
  enable_vc_hg     1
)

typeset -A _hp_s
_hp_s=(
  prompt         "•"
  user_auth_krb  ""
  user_priv_root "√"
  user_priv_sudo "√"
  vc_git         "±"
  vc_hg          "☿"
  vc_staged      "+"
  vc_changed     "!"
  vc_untracked   "?"
  vc_incoming    "⇣"
  vc_outgoing    "⇡"
  env_proxy      "@"
)

typeset -A _hp_c
_hp_c=(
  host           "%F{blue}"
  pwd            "%F{cyan}"
  prompt         "%f"
  prompt_a       "%F{red}"
  prompt_x       "%F{blue}"
  user_auth_krb  "%F{green}"
  user_unauth    "%F{red}"
  user_priv_root "%F{red}"
  user_priv_sudo "%F{yellow}"
  vc_git         "%F{blue}"
  vc_hg          "%F{blue}"
  vc_branch      "%F{blue}"
  vc_file_status "%F{blue}"
  vc_repo_status "%F{blue}"
  user           "%F{blue}"
  user_root      "%F{red}"
  env_proxy      "%F{green}"
)

## Async Storage #######################################################

# Set up temporary files for async items
if [ -z $_hp_async_file ]; then
  _hp_async_file="$(mktemp)"
fi
if [ -z $_hp_async_x_file ]; then
  _hp_async_x_file="$(mktemp)"
fi

# Associative arrays for async data results
typeset -gA _hp_git
typeset -gA _hp_gitx
typeset -gA _hp_hg
typeset -gA _hp_hgx

## Utility functions ###################################################

function _hp_search_up {
  local dir
  dir="$PWD"
  while [[ -n "$dir" ]]; do
    [[ -d "$dir/$1" ]] && return 0
    dir="${dir%/*}"
  done
  return 1
}

function _hp_test {
  _hp_session=other
  _hp_login_user=nobody
}

## Formatting Parts of the Prompt ######################################

function _hp_fmt_user_host {
  if (( EUID == 0 )) || [ "$USER" != "$_hp_login_user" ]; then
    echo -n "%(!,$_hp_c[user_root],$_hp_c[user])%n"
  fi
  if [ "$_hp_session" != "local" ]; then
    echo -n "$_hp_c[host]@%m"
  fi
}

function _hp_fmt_pwd {
  (( $_hp_conf[enable_pwd] )) || return
  echo "$_hp_c[pwd]%~"
}

function _hp_fmt_prompt_symbol {
  if (( ${_hp_async_pid:-0} > 0 )); then
    echo "$_hp_c[prompt_a]$_hp_s[prompt]%f "
  elif (( ${_hp_async_x_pid:-0} > 0 )); then
    echo "$_hp_c[prompt_x]$_hp_s[prompt]%f "
  else
    echo "$_hp_c[prompt]$_hp_s[prompt]%f "
  fi
}

function _hp_fmt_git {
  if (( ${_hp_git[active]:-0} )); then
    echo -n "$_hp_c[vc_git]$_hp_s[vc_git] "
    echo -n "$_hp_c[vc_branch]$_hp_git[branch]"
    if (( $_hp_git[staged] + $_hp_git[unstaged] + $_hp_git[untracked] > 0 )); then
      echo -n " $_hp_c[vc_file_status]"
      (( $_hp_git[staged] > 0 )) && echo -n "$_hp_s[vc_staged]"
      (( $_hp_git[unstaged] > 0 )) && echo -n "$_hp_s[vc_changed]"
      (( $_hp_git[untracked] > 0 )) && echo -n "$_hp_s[vc_untracked]"
    fi
    if (( ${_hp_gitx[incoming]:-0} + ${_hp_gitx[outgoing]:-0} > 0 )); then
      echo -n " $_hp_c[vc_repo_status]"
      (( ${_hp_gitx[incoming]:-0} > 0 )) && echo -n "$_hp_s[vc_incoming]"
      (( ${_hp_gitx[outgoing]:-0} > 0 )) && echo -n "$_hp_s[vc_outgoing]"
    fi
    echo "%f"
  fi
}

function _hp_fmt_hg {
  if (( ${_hp_hg[active]:-0} )); then
    echo -n "$_hp_c[vc_hg]$_hp_s[vc_hg] "
    echo -n "$_hp_c[vc_branch]$_hp_hg[branch]"
    if (( $_hp_hg[changed] + $_hp_hg[untracked] > 0 )); then
      echo -n " $_hp_c[vc_file_status]"
      (( $_hp_hg[changed] > 0 )) && echo -n "$_hp_s[vc_changed]"
      (( $_hp_hg[untracked] > 0 )) && echo -n "$_hp_s[vc_untracked]"
    fi
    if (( ${_hp_hgx[incoming]:-0} + ${_hp_hgx[outgoing]:-0} > 0 )); then
      echo -n " $_hp_c[vc_repo_status]"
      (( ${_hp_hgx[incoming]:-0} > 0 )) && echo -n "$_hp_s[vc_incoming]"
      (( ${_hp_hgx[outgoing]:-0} > 0 )) && echo -n "$_hp_s[vc_outgoing]"
    fi
    echo "%f"
  fi
}

function _hp_fmt_privileges {
  (( $_hp_conf[enable_priv] )) || return
  local _hp_priv_root=0
  local _hp_priv_sudo=0
  if (( EUID == 0 )); then
    _hp_priv_root=1
  elif (( $_hp_conf[enable_priv_sudo] )); then
    if sudo -n true 2>/dev/null; then
      _hp_priv_sudo=1
    fi
  fi
  if (( $_hp_priv_root )); then
    echo -n "$_hp_c[user_priv_root]$_hp_s[user_priv_root]%f"
  elif (( $_hp_priv_sudo )); then
    echo -n "$_hp_c[user_priv_sudo]$_hp_s[user_priv_sudo]%f"
  fi
  if (( $_hp_conf[enable_priv_krb] )); then
    if (( $+commands[klist] )); then
      if klist >/dev/null 2>&1; then
        echo -n "$_hp_c[user_auth_krb]$_hp_s[user_auth_krb]%f"
      else
        echo -n "$_hp_c[user_unauth]$_hp_s[user_auth_krb]%f"
      fi
    fi
  fi
  echo
}

function _hp_fmt_env {
  (( $_hp_conf[enable_env] )) || return
  if (( $_hp_conf[enable_env_proxy] )) && [ -n "$http_proxy" ]; then
    echo -n "$_hp_c[env_proxy]$_hp_s[env_proxy]"
  fi
  echo "%f"
}

## Putting it all together #############################################

function _hp_fmt_prompt {
  echo -n \
       $(_hp_fmt_user_host) \
       $(_hp_fmt_pwd)'%-40(l| |\n)'$(_hp_fmt_prompt_symbol)
  echo " "
}

function _hp_fmt_rprompt {
  echo -n " "
  echo $(_hp_fmt_git) \
       $(_hp_fmt_hg) \
       $(_hp_fmt_env) \
       $(_hp_fmt_privileges)
}

_hp_set_running=0
_hp_set_rerun=0

function _hp_set {
  if (( _hp_set_running )); then
    _hp_set_rerun=1
    return
  fi
  _hp_set_running=1
  while (( _hp_set_running )); do
    PROMPT="$(_hp_fmt_prompt)"
    RPROMPT="$(_hp_fmt_rprompt)"
    zle && zle .reset-prompt
    if (( _hp_set_rerun )); then
      _hp_set_rerun=0
    else
      _hp_set_running=0
    fi
  done
}

## Asynchronous git process (slow and fast) ############################

function _hp_git_branch {
  local branch
  if ! branch="$(\git symbolic-ref --short -q HEAD 2>/dev/null)"; then
    branch="$(\git rev-parse --short -q HEAD 2>/dev/null)"
  fi
  echo $branch
}

function _hp_async_git {
  _hp_git=( active 0 )
  if (( $_hp_conf[enable_vc_git] )) && (( $+commands[git] )) && _hp_search_up .git; then
    _hp_git[active]=1
    _hp_git[branch]="$(_hp_git_branch)"
    _hp_git[staged]="$(
      LC_ALL=C \git status --porcelain 2>/dev/null | \grep '^[^ ?]' | \wc -l)"
    _hp_git[unstaged]="$(
      LC_ALL=C \git status --porcelain 2>/dev/null | \grep '^.[^ ?]' | \wc -l)"
    _hp_git[untracked]="$(
      LC_ALL=C \git status --porcelain 2>/dev/null | \grep '^??' | \wc -l)"
  fi
  typeset -p _hp_git
}

function _hp_async_gitx {
  _hp_gitx=()
  if (( $_hp_conf[enable_vc_git] )) && (( $+commands[git] )) && _hp_search_up .git; then
    branch="$(_hp_git_branch)"
    remote="$(\git config --get branch.${branch}.remote 2>/dev/null)"
    if [[ -n "$remote" ]]; then
      remote_branch="$(\git config --get branch.${branch}.merge 2>/dev/null)"
      if [[ -n "$remote_branch" ]]; then
        remote_branch="${remote_branch/refs\/heads/refs/remotes/$remote}"
        _hp_gitx[incoming]="$(\git rev-list --count HEAD..$remote_branch 2>/dev/null)"
        _hp_gitx[outgoing]="$(\git rev-list --count $remote_branch..HEAD 2>/dev/null)"
      fi
    fi
  fi
  typeset -p _hp_gitx
}

## Asynchronous Mercurial processing (slow and fast) ###################

function _hp_async_hg {
  _hp_hg=( active 0 )
  if (( $_hp_conf[enable_vc_hg] )) && (( $+commands[hg] )) && _hp_search_up .hg; then
    _hp_hg[active]=1
    _hp_hg[branch]="$(\hg branch 2>/dev/null)"
    _hp_hg[changed]="$(\hg status -mar 2>/dev/null | \wc -l)"
    _hp_hg[untracked]="$(\hg status -du 2>/dev/null | \wc -l)"
  fi
  typeset -p _hp_hg
}

function _hp_async_hgx {
  _hp_hgx=()
  if (( $_hp_conf[enable_vc_hg] )) && (( $+commands[hg] )) && _hp_search_up .hg; then
    _hp_hgx[incoming]="$(\hg incoming --quiet 2>/dev/null | wc -l)"
    _hp_hgx[outgoing]="$(\hg outgoing --quiet 2>/dev/null | wc -l)"
  fi
  typeset -p _hp_hgx
}

## Fast asynchronous process ###########################################

function _hp_async_kill {
  if (( ${_hp_async_pid:-0} > 0 )); then
    kill -KILL "$_hp_async_pid" >/dev/null 2>&1
    _hp_async_pid=0
  fi
}

function _hp_async {
  # We kill on directory change, otherwise keep working
  (( $_hp_conf[enable_async] )) || return
  (( ${_hp_async_pid:-0} > 0 )) && return
  trap _hp_async_cb WINCH
  (
    _hp_async_git
    _hp_async_hg
    kill -WINCH $$ >/dev/null 2>&1
  ) > "$_hp_async_file" &!
  _hp_async_pid=$!
  _hp_set
}

function _hp_async_cb {
  . "$_hp_async_file"
  _hp_async_pid=0
  _hp_set
}

## Slow asynchronous process ###########################################

function _hp_async_x_kill {
  if (( ${_hp_async_x_pid:-0} > 0 )); then
    kill -KILL "$_hp_async_x_pid" >/dev/null 2>&1
    _hp_async_x_pid=0
  fi
}

function _hp_async_x {
  (( $_hp_conf[enable_async_x] )) || return
  (( ${_hp_async_x_pid:-0} > 0 )) && return
  trap _hp_async_x_cb USR1
  (
    _hp_async_gitx
    _hp_async_hgx
    kill -USR1 $$ >/dev/null 2>&1) > "$_hp_async_x_file" &!
  _hp_async_x_pid=$!
  _hp_set
}

function _hp_async_x_cb {
  . "$_hp_async_x_file"
  _hp_async_x_pid=0
  _hp_set
}

## Shell callbacks #####################################################

function _hp_chpwd {
  _hp_async_kill
  _hp_async_x_kill
  _hp_git=()
  _hp_gitx=()
  _hp_hg=()
  _hp_hgx=()
}

function _hp_precmd {
  _hp_async
  _hp_async_x
  _hp_set
}

## Initial setup and hooking the shell #################################

function _hp_get_session {
  # Figure out what sort of session we're in
  if [[ -n "${SSH_CLIENT-}${SSH2_CLIENT-}${SSH_TTY-}" ]]; then
    _hp_session=ssh
  else
    local who_am_i="$(LANG=C who am i)"
    local parent="$(ps -o comm= -p $PPID 2> /dev/null)"
    if [[ "$whoami" != *'('* ]]; then
      _hp_session=local
    elif [[ "$parent" = "su" || "$parent" = "sudo" ]]; then
      _hp_session=su
    else
      _hp_session=other
    fi
  fi
  _hp_login_user="$(logname 2>/dev/null || echo "$LOGNAME")"
}

# Kill async processes and clear data, in case of re-source
_hp_chpwd

# Find out about our current session
_hp_get_session

# We need control of zle, and ability to hook events
zmodload zsh/zle
autoload -Uz add-zsh-hook

# Hook chpwd to reset processes, precmd to generate the prompt
add-zsh-hook chpwd _hp_chpwd
add-zsh-hook precmd _hp_precmd
