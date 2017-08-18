#!/bin/zsh

# Hypatian ZSH Prompt Theme
# Katherine Prevost <kat@hypatian.org>

# Requires zsh 5.3+

# Copyright 2017 Katherine Anne Prevost
#
# This work is licensed under a Creative Commons Attribution 4.0
# International License.
# CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/)

# Inspired by ideas from:
#   slimline (https://github.com/mgee/slimline)
#   liquidprompt (https://github.com/nojhan/liquidprompt)

# Example:
#
# username@hostname ~/src/repository •              ± master +!%? ⇣⇡ √º†
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
  enable_cwd       1
  enable_vc_root   1
  enable_priv      1
  enable_priv_sudo 1
  enable_auth_krb  1
  enable_vc_git    1
  enable_vc_hg     1
)

# Formatting for prompt components. s_*, e_* pairs are used at start
# and end of text information items or sections. The other entries are
# individual symbols with optional formatting, or in the case of
# $_hp_f[cwd], the actual format used (since that's one of the most
# likely components for customization.)

# Rather than making them part of _hp_f or _hp_conf, we set PROMPT and RPROMPT
# here so that whatever loads us can override them afterwards.
setopt prompt_subst
PROMPT='$(_hp_fmt_user_host)$(_hp_fmt_cwd) $(_hp_fmt_prompt_symbol)'
RPROMPT=' $(_hp_fmt_vc_info)$(_hp_fmt_env)$(_hp_fmt_privileges)'

typeset -A _hp_f=(
  cwd              "%F{cyan}%(5~,%-1~/…/%2~,%~)%f"
  env_proxy        "%F{green}º"
  prompt_sym       "%b%f• "
  prompt_sym_a     "%b%F{red}•%f "
  prompt_sym_x     "%b%F{blue}•%f "
  user_auth_krb_ok "%F{green}†"
  user_auth_krb_no "%F{red}†"
  user_priv_root   "%F{red}√"
  user_priv_sudo   "%F{blue}√"
  vc_git           "±"
  vc_hg            "☿"
  vc_staged        "%F{green}+"
  vc_changed       "%F{yellow}!"
  vc_untracked     "%F{red}?"
  vc_unresolved    "%F{red}%%"
  vc_incoming      "%F{yellow}⇣"
  vc_outgoing      "%F{yellow}⇡"
  vc_diverged      "%F{red}⇅"

  s_env            "%F{blue}"
  e_env            "%f"
  s_host           "%F{blue}@"
  e_host           "%f "
  s_vc             " %F{blue}"
  e_vc             "%f"
  s_vc_branch      " %F{blue}"
  e_vc_branch      "%F{blue}"
  s_vc_file_status " %F{blue}"
  e_vc_file_status "%F{blue}"
  s_vc_repo_status " %F{blue}"
  e_vc_repo_status "%F{blue}"
  s_vc_root        "%F{blue}["
  e_vc_root        "]%F{blue}"
  s_user           "%F{blue}"
  e_user           "%f"
  s_user_root      "%F{red}"
  e_user_root      "%f"
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
typeset -gA _hp_hg
typeset -g _hp_priv_sudo
typeset -g _hp_auth_krb

typeset -gA _hp_gitx
typeset -gA _hp_hgx

## Utility functions ###################################################

function _hp_search_up {
  local dir
  dir="$PWD"
  while [[ -n "$dir" ]]; do
    if [[ -e "$dir/$1" ]]; then
      echo "$dir"
      return 0
    fi
    dir="${dir%/*}"
  done
  return 1
}

function _hp_test {
  _hp_session=other
  _hp_login_user=nobody
}

## Formatting Parts of the Prompt ######################################

function _hp_fmt_user {
  if (( EUID == 0 )) || [ "$USER" != "$_hp_login_user" ]; then
    echo -n "%(!,$_hp_f[s_user_root]%n$_hp_f[e_user_root],$_hp_f[s_user]%n$_hp_f[e_user])"
  fi
}

function _hp_fmt_host {
  if [ "$_hp_session" != "local" ]; then
    echo -n "$_hp_f[s_host]%m$_hp_f[e_host]"
  fi
}

function _hp_fmt_user_host { _hp_fmt_user; _hp_fmt_host; }

function _hp_fmt_cwd {
  (( $_hp_conf[enable_cwd] )) || return
  echo -n "$_hp_f[cwd]"
}

function _hp_fmt_prompt_symbol {
  if (( ${_hp_async_pid:-0} > 0 )); then
    echo -n "$_hp_f[prompt_sym_a]"
  elif (( ${_hp_async_x_pid:-0} > 0 )); then
    echo -n "$_hp_f[prompt_sym_x]"
  else
    echo -n "$_hp_f[prompt_sym]"
  fi
}

# _hp_fmt_vcs fmt_name branch nrof_staged _unstaged _conflicted _untracked \
#     nrof_incoming _outgoing vc_root
function _hp_fmt_vcs {
  echo -n "$_hp_f[s_vc]$_hp_f[$1]"
  if (( $_hp_conf[enable_vc_root] )) && [ -n "$9" ]; then
    echo -n "$_hp_f[s_vc_root]$9$_hp_f[e_vc_root]"
  fi
  echo -n "$_hp_f[s_vc_branch]$2$_hp_f[e_vc_branch]"
  if (( ${3:-0} + ${4:-0} + ${5:-0} + ${6:-0} > 0 )); then
    echo -n "$_hp_f[s_vc_file_status]"
    (( ${3:-0} > 0 )) && echo -n "$_hp_f[vc_staged]"
    (( ${4:-0} > 0 )) && echo -n "$_hp_f[vc_changed]"
    (( ${5:-0} > 0 )) && echo -n "$_hp_f[vc_unresolved]"
    (( ${6:-0} > 0 )) && echo -n "$_hp_f[vc_untracked]"
    echo -n "$_hp_f[e_vc_file_status]"
  fi
  if (( ${7:-0} + ${8:-0} > 0 )); then
    echo -n "$_hp_f[s_vc_repo_status]"
    case "${7:-0},${8:-0}" in
      *,0) echo -n "${_hp_f[vc_incoming]}" ;;
      0,*) echo -n "${_hp_f[vc_outgoing]}" ;;
      *,*) echo -n "${_hp_f[vc_diverged]}" ;;
    esac
    echo -n "$_hp_f[e_vc_repo_status]"
  fi
  echo -n "$_hp_f[e_vc]"
}

function _hp_fmt_git {
  (( ${_hp_git[active]:-0} )) || return
  _hp_fmt_vcs vc_git "${_hp_git[branch]}" \
    "$_hp_git[staged]" "$_hp_git[unstaged]" "$_hp_git[unresolved]" "$_hp_git[untracked]" \
    "${_hp_gitx[incoming]}" "${_hp_gitx[outgoing]}" "${_hp_git[vc_root]##*/}"
}

function _hp_fmt_hg {
  (( ${_hp_hg[active]:-0} )) || return
  _hp_fmt_vcs vc_hg "${_hp_hg[branch]}" \
    "$_hp_hg[staged]" "$_hp_hg[unstaged]" "$_hp_hg[unresolved]" "$_hp_hg[untracked]" \
    "${_hp_hgx[incoming]}" "${_hp_hgx[outgoing]}" "${_hp_hg[vc_root]##*/}"
}

function _hp_fmt_vc_info { _hp_fmt_git; _hp_fmt_hg }

function _hp_fmt_privileges {
  (( $_hp_conf[enable_priv] )) || return
  local _hp_priv_root=0
  if (( EUID == 0 )); then
    _hp_priv_root=1
  fi
  if (( $_hp_priv_root )); then
    echo -n "$_hp_f[user_priv_root]"
  elif (( $_hp_conf[enable_priv_sudo] )) && (( $_hp_priv_sudo )); then
    echo -n "$_hp_f[user_priv_sudo]"
  fi
  if (( $_hp_conf[enable_auth_krb] )) && [ -n "$_hp_auth_krb" ]; then
    if (( $_hp_auth_krb )); then
      echo -n "$_hp_f[user_auth_krb_ok]"
    else
      echo -n "$_hp_f[user_auth_krb_no]"
    fi
  fi
  echo -n ' '
}

function _hp_fmt_env {
  (( $_hp_conf[enable_env] )) || return
  echo -n "$_hp_f[s_env]"
  if (( $_hp_conf[enable_env_proxy] )) && [ -n "$http_proxy" ]; then
    echo -n "$_hp_f[env_proxy]"
  fi
  echo -n "$_hp_f[e_env]"
}

## Putting it all together #############################################

_hp_set_running=0
_hp_set_rerun=0

function _hp_set {
  if (( _hp_set_running )); then
    _hp_set_rerun=1
    return
  fi
  _hp_set_running=1
  while (( _hp_set_running )); do
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
  if (( $_hp_conf[enable_vc_git] )) && (( $+commands[git] )); then
    if vc_root="$(_hp_search_up .git)"; then
      _hp_git[active]=1
      _hp_git[vc_root]="$vc_root"
      _hp_git[branch]="$(_hp_git_branch)"
      _hp_git[staged]="$(
        LC_ALL=C \git status --porcelain 2>/dev/null | \grep '^[^ ?]' | \wc -l)"
      _hp_git[unstaged]="$(
        LC_ALL=C \git status --porcelain 2>/dev/null| \grep '^.[^ ?]' | \wc -l)"
      _hp_git[untracked]="$(
        LC_ALL=C \git status --porcelain 2>/dev/null | \grep '^??' | \wc -l)"
      _hp_git[unresolved]="$(
        LC_ALL=C \git status --porcelain 2>/dev/null | \grep '^UU' | \wc -l)"
    fi
  fi
  typeset -p _hp_git
}

# _hp_git_remote_branch <remote> <branch>
# Get the sha the branch points to on the remote using `git ls-remote`.
# If that fails, look for our local mirror in refs/remotes/
function _hp_git_remote_ref {
  \git ls-remote "$1" "refs/heads/$2" 2>/dev/null | cut -f1 \
    || \git show-ref --verify -s "refs/remotes/$1/$2" 2>/dev/null
}

function _hp_git_delta {
  local upstream="$(\git rev-parse --symbolic-full-name "HEAD@{$1}" 2>&1)"
  if [[ $upstream ]]; then
    local upstream_remote="$(echo "${upstream}" | cut -d/ -f3)"
    local upstream_branch="$(echo "${upstream}" | cut -d/ -f4-)"
    local upstream_ref="$(_hp_git_remote_ref "$upstream_remote" "$upstream_branch")"

    # If we have upstream_ref locally, we can get an exact count.
    if [[ $upstream_ref ]] && \git cat-file -e "${upstream_ref}"; then
      \git rev-list --count "$2${upstream_ref}$3" 2>/dev/null

    else
      # Otherwise, either:
      # - it's a commit on the remote we don't have yet, or
      # - we have a remote configured but have never fetched from it and can't
      #   ls-remote it
      # In either case, assume we have at least one incoming commit.
      echo -n 1
    fi
  fi
}

function _hp_async_gitx {
  _hp_gitx=()
  if (( $_hp_conf[enable_vc_git] )) && (( $+commands[git] )) && _hp_search_up .git >/dev/null; then
    local branch="$(_hp_git_branch)"
    _hp_gitx[incoming]="$(_hp_git_delta upstream HEAD.. '')"
    _hp_gitx[outgoing]="$(_hp_git_delta push '' ..HEAD)"
  fi
  typeset -p _hp_gitx
}

## Asynchronous Mercurial processing (slow and fast) ###################

function _hp_async_hg {
  _hp_hg=( active 0 )
  if (( $_hp_conf[enable_vc_hg] )) && (( $+commands[hg] )); then
    if vc_root="$(_hp_search_up .hg)"; then
      typeset -p _hp_vc_root
      _hp_hg[active]=1
      _hp_hg[vc_root]="$vc_root"
      _hp_hg[branch]="$(\hg --config 'alias.branch = branch' branch 2>/dev/null)"
      _hp_hg[changed]="$(\hg --config 'alias.status = status' status -mar 2>/dev/null | \wc -l)"
      _hp_hg[untracked]="$(\hg --config 'alias.status = status' status -du 2>/dev/null | \wc -l)"
      _hp_hg[unresolved]="$(\hg --config 'alias.resolve = resolve' resolve -l 'set:unresolved()' 2>/dev/null | \wc -l)"
    fi
  fi
  typeset -p _hp_hg
}

function _hp_async_hgx {
  _hp_hgx=()
  if (( $_hp_conf[enable_vc_hg] )) && (( $+commands[hg] )) && _hp_search_up .hg >/dev/null; then
    _hp_hgx[incoming]="$(\hg --config 'alias.incoming = incoming' incoming --quiet 2>/dev/null | wc -l)"
    _hp_hgx[outgoing]="$(\hg --config 'alias.outgoing = outgoing' outgoing --quiet 2>/dev/null | wc -l)"
  fi
  typeset -p _hp_hgx
}

function _hp_async_sudo {
  _hp_priv_sudo=0
  if (( $_hp_conf[enable_priv_sudo] )); then
    if sudo -n true 2>/dev/null; then
      _hp_priv_sudo=1
    fi
  fi
  typeset -p _hp_priv_sudo
}

function _hp_async_krb {
  _hp_auth_krb=""
  if (( $_hp_conf[enable_auth_krb] )) && (( $+commands[klist] )); then
    if klist -s >/dev/null 2>&1; then
      _hp_auth_krb=1
    else
      _hp_auth_krb=0
    fi
  fi
  typeset -p _hp_auth_krb
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
    _hp_async_sudo
    _hp_async_krb
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
  unset _hp_vc_root
  _hp_git=()
  _hp_hg=()
  _hp_vc_root=""
  _hp_priv_sudo=0
  _hp_auth_krb=""
  _hp_gitx=()
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
    local whoami="$(LANG=C who am i)"
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
