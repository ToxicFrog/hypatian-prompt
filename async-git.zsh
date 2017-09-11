## Asynchronous git process (slow and fast) ############################

typeset -A _hp_git _hp_gitx

function _hp_fmt_git {
  (( ${_hp_git[active]:-0} )) || return
  _hp_fmt_vcs vc_git ${(kv)_hp_git[@]} ${(kv)_hp_gitx[@]}
}

function _hp_git_branch {
  local branch
  if ! branch="$(\git symbolic-ref --short -q HEAD 2>/dev/null)"; then
    branch="$(\git rev-parse --short -q HEAD 2>/dev/null)"
  fi
  echo $branch
}

function _hp_git_root {
  git rev-parse --show-toplevel 2>/dev/null
}

function _hp_async_git {
  _hp_git=( active 0 )
  if (( $_hp_conf[enable_vc_git] )) && (( $+commands[git] )); then
    if vc_root="$(_hp_git_root)"; then
      _hp_git[active]=1
      _hp_git[vc_root]="$vc_root"
      _hp_git[branch]="$(_hp_git_branch)"
      _hp_git[staged]="$(
        LC_ALL=C \git status --porcelain 2>/dev/null | \grep '^[^ ?]' | \wc -l)"
      _hp_git[changed]="$(
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
  if (( $_hp_conf[enable_vc_git] )) && (( $+commands[git] )) && _hp_git_root >/dev/null; then
    local branch="$(_hp_git_branch)"
    _hp_gitx[incoming]="$(_hp_git_delta upstream 'HEAD..%s')"
    (( _hp_gitx[errors] += $? ))
    _hp_gitx[outgoing]="$(_hp_git_delta push '%s..HEAD')"
    (( _hp_gitx[errors] += $? ))
  fi
  typeset -p _hp_gitx
}
