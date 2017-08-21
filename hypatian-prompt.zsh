#!/bin/zsh

# Hypatian ZSH Prompt Theme
# Katherine Prevost <kat@hypatian.org>

# Requires zsh 5.3+

# Copyright 2017 Katherine Anne Prevost
# Portions copyright 2017 Google
#
# Contributions from Ben Kelly
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

# Configure the components used in the prompts. _hp calls commands like
# _hp_fmt_user_host to simplify stringing components together. prompt_subst
# is used so that the substitutions happen at prompt display time.
setopt prompt_subst
PROMPT='$(_hp user_host cwd prompt_symbol)'
RPROMPT='$(_hp vc_info env privileges)'

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

typeset -A _hp_f=(
  prompt           '$(_hp user_host cwd) $(_hp prompt_symbol)'
  rprompt          ' $(_hp vc_info env privileges)'
  cwd              "%F{cyan}%(5~,%-1~/…/%2~,%~)%f"
  env_proxy        "%F{green}º"
  prompt_sym       "%b%u%s%f• "
  prompt_sym_a     "%b%u%s%k%F{red}•%f "
  prompt_sym_x     "%b%u%s%k%F{blue}•%f "
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
  vc_error         "%F{red}⁉"

  s_env            " %F{blue}"
  e_env            "%f"
  s_host           "%F{blue}@"
  e_host           "%f "
  s_priv           "%F{blue}"
  e_priv           "%f"
  s_vc             " %F{blue}"
  e_vc             "%f"
  s_vc_branch      " %F{blue}"
  e_vc_branch      "%F{blue}"
  s_vc_status      " %F{blue}"
  e_vc_status      "%f"
  s_vc_file_status "%F{blue}"
  e_vc_file_status "%F{blue}"
  s_vc_repo_status "%F{blue}"
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
if [[ ! $_hp_async_file ]]; then
  _hp_async_file="$(mktemp)"
fi
if [[ ! $_hp_async_x_file ]]; then
  _hp_async_x_file="$(mktemp)"
fi

# Mutex used to guard prompt redrawing.
# The prompt is drawn (up to) three times: as soon as it's done initializing,
# after the fast async process finishes, and after the slow async process
# finishes. The latter two are triggered by signals, which can potentially
# arrive in the middle of a prompt redraw, causing graphical glitches.
# So, the mutex guards both the `zle .reset-prompt` call that actually redraws
# the prompt, and the `kill` calls used to trigger additional prompt redraws.
# (Why not just guard the redraw? Because signal handlers happen in the same
# process as the "main" redraw, and recursive flock()s are a no-op, so that
# wouldn't provide any actual protection.)
if [[ ! $_hp_mutex ]]; then
  _hp_mutex="$(mktemp)"
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
  _hp_session=(test local)
  _hp_login_user=nobody
}

## Formatting Parts of the Prompt ######################################

function _hp_fmt_user {
  if (( EUID == 0 )) || [ "$USER" != "$_hp_login_user" ]; then
    echo -n "%(!,$_hp_f[s_user_root]%n$_hp_f[e_user_root],$_hp_f[s_user]%n$_hp_f[e_user])"
  fi
}

function _hp_fmt_host {
  if [[ ! "${_hp_session[(r)local]}" ]]; then
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

function _hp_fmt_vcs_repo_status {
  local incoming="${1:=0}"
  local outgoing="${2:=0}"
  local errors="${3:=0}"

  (( incoming + outgoing + errors )) || return

  echo -n "$_hp_f[s_vc_repo_status]"
  case "$incoming,$outgoing" in
    0,0) ;;
    *,0) echo -n "${_hp_f[vc_incoming]}" ;;
    0,*) echo -n "${_hp_f[vc_outgoing]}" ;;
    *,*) echo -n "${_hp_f[vc_diverged]}" ;;
  esac
  (( $errors )) && echo -n "${_hp_f[vc_error]}"
  echo -n "$_hp_f[e_vc_repo_status]"
}

# _hp_fmt_vcs fmt_name <key value> <key value>...
function _hp_fmt_vcs {
  local fmt_name="$1"; shift
  typeset -A info=("$@")

  echo -n "$_hp_f[s_vc]$_hp_f[$fmt_name]"
  if (( $_hp_conf[enable_vc_root] )) && [[ -n "${info[vc_root]}" ]]; then
    echo -n "$_hp_f[s_vc_root]${info[vc_root]}$_hp_f[e_vc_root]"
  fi
  [[ ${info[branch]} ]] &&  echo -n "$_hp_f[s_vc_branch]${info[branch]}$_hp_f[e_vc_branch]"

  for key in staged changed unresolved untracked incoming outgoing errors; do
    local $key=${info[$key]:=0}
  done

  if (( $staged + $changed + $unresolved + $untracked
        + $incoming + $outgoing + $errors > 0 )); then
    echo -n "$_hp_f[s_vc_status]"
    if (( $staged + $changed + $unresolved + $untracked > 0 )); then
      echo -n "$_hp_f[s_vc_file_status]"
      (( $staged > 0 )) && echo -n "$_hp_f[vc_staged]"
      (( $changed > 0 )) && echo -n "$_hp_f[vc_changed]"
      (( $unresolved > 0 )) && echo -n "$_hp_f[vc_unresolved]"
      (( $untracked > 0 )) && echo -n "$_hp_f[vc_untracked]"
      echo -n "$_hp_f[e_vc_file_status]"
    fi
    _hp_fmt_vcs_repo_status "$incoming" "$outgoing" "$errors"
    echo -n "$_hp_f[e_vc_status]"
  fi
  echo -n "$_hp_f[e_vc]"
}

function _hp_fmt_git {
  (( ${_hp_git[active]:-0} )) || return
  _hp_fmt_vcs vc_git "${(kv)_hp_git[@]}" "${(kv)_hp_gitx[@]}"
}

function _hp_fmt_hg {
  (( ${git_hp_hg[active]:-0} )) || return
  _hp_fmt_vcs vc_hg "${(kv)_hp_hg[@]}" "${(kv)_hp_hgx[@]}"
}

function _hp_fmt_vc_info { _hp_fmt_git; _hp_fmt_hg }

function _hp_fmt_privileges {
  (( $_hp_conf[enable_priv] )) || return
  echo -n "$_hp_f[s_priv]"
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
  echo -n "$_hp_f[e_priv]"
}

function _hp_fmt_env {
  (( $_hp_conf[enable_env] )) || return
  echo -n "$_hp_f[s_env]"
  if (( $_hp_conf[enable_env_proxy] )) && [ -n "$http_proxy" ]; then
    echo -n "$_hp_f[env_proxy]"
  fi
  echo -n "$_hp_f[e_env]"
}

# Function to ease calling formatters from PROMPT and RPROMPT
function _hp {
  while [[ $1 ]]; do
    "_hp_fmt_$1"
    shift
  done
}

## Putting it all together #############################################

function _hp_set { zle && zle reset-prompt; }

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
  local upstream="$(\git rev-parse --symbolic-full-name "HEAD@{$1}" 2>/dev/null)"
  if [[ ! $upstream ]]; then
    # No upstream configured.
    echo -n 0
    return 0
  fi

  # Expand the ref -- as it exists on the remote if possible, otherwise as it
  # existed last time we looked at it.
  local upstream_remote="$(echo "${upstream}" | cut -d/ -f3)"
  local upstream_branch="$(echo "${upstream}" | cut -d/ -f4-)"
  local upstream_ref="$(_hp_git_remote_ref "$upstream_remote" "$upstream_branch")"

  if [[ ! $upstream_ref ]]; then
    # Oops! We have it configured but we have no idea what it actually is.
    # Report an error.
    echo -n 0
    return 1
  fi

  # If we have upstream_ref locally, we can get an exact count.
  if \git cat-file -e "${upstream_ref}"; then
    \git rev-list --count "$(printf "$2" "$upstream_ref")" 2>/dev/null
    return 0
  fi

  # Otherwise our behaviour depends on whether it's upstream (fetch) or push.
  # Upstream we assume not having it means we have at least one incoming commit.
  # Push we diff against the most recent version we have.
  case $1 in
    upstream) echo -n 1;;
    push) \git rev-list --count "$(printf "$2" "$upstream")";;
    *) echo -n 0; return 0;;
  esac
}

function _hp_async_gitx {
  _hp_gitx=()
  if (( $_hp_conf[enable_vc_git] )) && (( $+commands[git] )) && _hp_search_up .git >/dev/null; then
    local branch="$(_hp_git_branch)"
    _hp_gitx[incoming]="$(_hp_git_delta upstream 'HEAD..%s')"
    (( _hp_gitx[errors] += $? ))
    _hp_gitx[outgoing]="$(_hp_git_delta push '%s..HEAD')"
    (( _hp_gitx[errors] += $? ))
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
    flock -F "${_hp_mutex}" kill -WINCH $$ >/dev/null 2>&1
  ) > "$_hp_async_file" &!
  _hp_async_pid=$!
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
    flock -F "${_hp_mutex}" kill -USR1 $$ >/dev/null 2>&1
  ) > "$_hp_async_x_file" &!
  _hp_async_x_pid=$!
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
  PROMPT='%{$(flock 9)%}'"${_hp_f[prompt]}"
  RPROMPT="${_hp_f[rprompt]}"'%{$(flock -u 9)%}'
  _hp_async
  _hp_async_x
}

## Initial setup and hooking the shell #################################

# _hp_grep_parents key pattern PID
# Check if PID or any of its parents have a command matching pattern.
# If so, emit key and return 0.
# If not, emit nothing and return 1.
function _hp_grep_parents {
  (( $3 <= 1 )) && return 1
  if ps -o comm= -p "$3" | egrep -q "$2"; then
    echo -n "$1"
    return 0
  fi
  _hp_grep_parents "$1" "$2" $(ps -o ppid= -p $3)
}

# Figure out what sort of session we're in.
# Populates _hp_login_user with the name of the user we logged in as (not
# necessarily the user we are right now, if su is involved!)
# Populates _hp_session with a list of strings indicating the kind of session
# we're in.
function _hp_get_session {
  _hp_login_user="$(logname 2>/dev/null || echo "$LOGNAME")"
  _hp_session=(
    $(_hp_grep_parents "ssh remote" ssh $PPID)
    # We have no way of checking if the user is attached to tmux/screen remotely
    # or not, so we make the worst case assumption that it's remote.
    $(_hp_grep_parents "screen remote" 'tmux|screen' $PPID)
    $(_hp_grep_parents su '^(su|sudo)$' $PPID)
  )

  # Sessions that aren't remote are local.
  if [[ ! ${_hp_session[(r)remote]} ]]; then
    _hp_session+=(local)
  fi
}

function _hp_atexit {
  _hp_async_kill
  _hp_async_x_kill
  rm -f "${_hp_async_file}" "${_hp_async_x_file}" "${_hp_mutex}"
}

setopt prompt_subst
exec 9> "${_hp_mutex}"

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
add-zsh-hook zshexit _hp_atexit
