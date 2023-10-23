#!/bin/zsh

# Hypatian ZSH Prompt Theme
# Katherine Prevost <kat@hypatian.org>

# Requires zsh 5.3+

# Copyright 2017 Katherine Anne Prevost
# Portions copyright 2017 Google
#
# Contributions from Rebecca Kelly
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

# Configure the prompt features.
# Set after sourcing this using:
#   _hp_conf[enable_async] = 0
# and so on.
typeset -A _hp_conf
_hp_conf=(
  enable_async     1  # Enable background fetching of information.
  enable_env       1  # Show information about environment.
  enable_env_proxy 1  #   Specifically, show $http_proxy.
  enable_cwd       1  # Show current directory.
  enable_vc_root   1  # Show VC root directory in VC info.
  enable_priv      1  # Show privilege information.
  enable_priv_sudo 1  #   Show sudo ability.
  enable_auth_krb  1  #   Show Kerberos status.
  enable_vc_git    1  # Show information about Git repos.
  enable_vc_hg     1  # Show information about Mercurial repos.
  enable_task      1  # Show Taskwarrior pending task counts.
  enable_chezmoi   1  # Show chezmoi target and source status

  # List of async background fetchers to run. Note that turning off
  # enable_async turns off all of these, and turning off individual features
  # (e.g. enable_vc_git 0) turns off the corresponding async fetchers, even
  # if they're turned on here.
  async            "hg git krb sudo hgx gitx task taskx chezmoi"

  # File to log errors to. Mostly useful for debugging the prompt.
  error_log        "/dev/null"
  #error_log        "$HOME/.zprompt-errors"

  # Taskwarrior configuration
  task_filter_critical  "+PENDING and +OVERDUE"
  task_filter_urgent    "+PENDING and -WAITING and (+ACTIVE or due.before:today+25h) and -OVERDUE"
  task_filter_soon      "+PENDING and -WAITING and (+ACTIVE or due.before:today+1w+25h or +next)"
)

# Formatting for prompt components. s_*, e_* pairs are used at start
# and end of text information items or sections. The other entries are
# individual symbols with optional formatting, or in the case of
# $_hp_f[cwd], the actual format used (since that's one of the most
# likely components for customization.)
typeset -A _hp_f=(
  # Left and right prompt. The _hp function takes a list of formatters to use
  # and calls them, equivalent to writing $(_hp_fmt_user_host)$(_hp_fmt_cwd)
  # ...etc out by hand.
  prompt           '$(_hp user_host cwd) $(_hp prompt_symbol)'
  rprompt          ' $(_hp vc_info env privileges)'

  # Working directory.
  cwd              "%F{cyan}%(5~,%-1~/…/%2~,%~)%f"

  # User prefix and suffix, for normal and root users.
  s_user           "%F{blue}"
  e_user           "%f"
  s_user_root      "%F{red}"
  e_user_root      "%f"

  # Hostname prefix and suffix.
  s_host           "%F{blue}@"
  e_host           "%f "

  # Command prompt, with and without async processes running.
  prompt_sym       "%b%u%s%f• "
  prompt_sym_a     "%b%u%s%k%F{red}•%f "

  # Privileges and authentication.
  s_priv           "%F{blue}"
    user_auth_krb_ok "%F{green}†"
    user_auth_krb_no "%F{red}†"
    user_priv_root   "%F{red}√"    # Are we root?
    user_priv_sudo   "%F{blue}√"   # Can we use sudo?
  e_priv           "%f"

  # Environment information.
  s_env            " %F{blue}"
    env_proxy        "%F{green}º"
  e_env            "%f"

  # Version control.
  s_vc             " %F{blue}"
    vc_git           "±"
    vc_hg            "☿"

    # VC root directory and current branch.
    s_vc_root        "%F{blue}["
    e_vc_root        "]%F{blue}"
    s_vc_branch      " %F{blue}"
    e_vc_branch      "%F{blue}"

    # VC file and commit status.
    s_vc_status      " %F{blue}"
      s_vc_file_status "%F{blue}"
        vc_staged        "%F{green}+"
        vc_changed       "%F{yellow}!"
        vc_untracked     "%F{red}?"
        vc_unresolved    "%F{red}%%"
      e_vc_file_status "%F{blue}"
      s_vc_repo_status "%F{blue}"
        vc_incoming      "%F{yellow}⇣"
        vc_outgoing      "%F{yellow}⇡"
        vc_diverged      "%F{red}⇅"
        vc_error         "%F{red}⁉"
      e_vc_repo_status "%F{blue}"
    e_vc_status      "%f"
  e_vc             "%f"

  # Taskwarrior
  s_task           " %B✓%b"
    task_sync        "%F{cyan}⇅%f"
    task_critical    "%B%F{red}"
    task_urgent      "%B%F{yellow}"
    task_soon        "%B%F{blue}★"
    task_alldone     "%B%F{purple}✪"
  e_task           "%f"

  # Chezmoi
  s_chezmoi             " ⌂"
    chezmoi_ok            "%B%F{green}✓"
    chezmoi_incoming      "%B%F{yellow}⇣"
    chezmoi_outgoing      "%B%F{red}⇅"
  e_chezmoi             "%f"
  # Used when in a chezmoi subshell
  s_chezmoi_sh          " %B%F{cyan}(⌂)"
  e_chezmoi_sh          "%f"
)

## Utility functions ###################################################

function _hp_test {
  _hp_session=(test local)
  _hp_login_user=nobody
}

## Formatting Parts of the Prompt ######################################

function _hp_fmt_user {
  if [[ $EUID == 0 || "$USER" != "$_hp_login_user" || "${_hp_session[(r)remote]}" ]] ; then
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
  if zpty -L | cut -d' ' -f2 | fgrep -q _hp_async; then
    echo -n "$_hp_f[prompt_sym_a]"
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
    echo -n "$_hp_f[s_vc_root]${info[vc_root]##*/}$_hp_f[e_vc_root]"
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

function _hp_fmt_vc_info { _hp_fmt_git; _hp_fmt_hg }

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

for lib in "$(dirname "$0")"/async-*.zsh; do
  source "$lib"
done

## Asynchronous process runners ########################################

zmodload zsh/zpty
typeset -A _hp_async_fds=()

function _hp_async_run_all {
  (( $_hp_conf[enable_async] )) || return
  for fn in ${(ps: :)_hp_conf[async]}; do
    # This will start a new run if one isn't already going, and will fail if
    # one is.
    if zpty _hp_async_$fn _hp_async_run_one $fn 2>/dev/null; then
      _hp_async_fds[$REPLY]=_hp_async_$fn
      zle -F $REPLY _hp_async_collect
    fi
  done
}

function _hp_async_run_one {
  # output LF rather than CR LF
  stty -onlcr

  # Workaround a bug in older versions of zsh where exiting zptys kill their
  # siblings.
  function zshexit {
    kill -KILL $$
    sleep 1 # Block for long enough for the signal to come through
  }

  _hp_async_$1 2>> ${_hp_conf[error_log]}
}

function _hp_async_collect {
  local name=${_hp_async_fds[$1]}

  # Remove the handler from the fd
  zle -F $1
  unset "_hp_async_fds[$1]"

  eval "$(zpty -r $name)" 2>> ${_hp_conf[error_log]}
  zpty -d $name
  zle && zle reset-prompt
}

function _hp_async_kill {
  for fd in ${(k)_hp_async_fds[@]}; do
    zle -F $fd
    zpty -d "${_hp_async_fds[$fd]}"
  done
}

## Shell callbacks #####################################################

function _hp_chpwd {
  _hp_async_kill
}

function _hp_precmd {
  PROMPT="${_hp_f[prompt]}"
  RPROMPT="${_hp_f[rprompt]}"
  _hp_async_run_all
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

# prompt_subst is needed for the prompt to work at all.
# prompt_cr and prompt_sp are needed for prompts not to clobber the last line
# of program output in some circumstances.
setopt prompt_subst prompt_cr prompt_sp

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
