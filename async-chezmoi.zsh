## Asynchronous ChezMoi processing #############################################

# The fast (synchronous) path just displays an indicator if you're in a CM
# subshell, or if you're in ~ and chezmoi is configured.
# The async path gives you an idea of `chezmoi status`, showing if everything
# is ok or if you have pending changes in the source-dir or in ~.
#
# TODO: use parts of async-git to fetch the CM source-dir status, so we can also
# display indicators if that has uncommited/untracked data or needs to sync.

typeset -A _hp_chezmoi

function _hp_fmt_chezmoi {
  (( ${+commands[chezmoi]} )) || return

  # Are we in a chezmoi subshell?
  if (( CHEZMOI )); then
    echo -n "${_hp_f[s_chezmoi_sh]}${_hp_f[e_chezmoi_sh]}"
    return
  fi

  # Don't display info if we aren't in ~
  [[ $PWD/ == $HOME/* ]] || return
  # Don't display it if the source-dir doesn't exist
  [[ -d "$(chezmoi source-path)" ]] || return

  echo -n "$_hp_f[s_chezmoi]"
  if (( ! _hp_chezmoi[active] )); then
    echo -n "$_hp_f[e_chezmoi]"
    return
  fi

  if (( _hp_chezmoi[incoming] + _hp_chezmoi[outgoing] )); then
    (( _hp_chezmoi[incoming] )) && echo -n "$_hp_f[chezmoi_incoming]"
    (( _hp_chezmoi[outgoing] )) && echo -n "$_hp_f[chezmoi_outgoing]"
  else
    echo -n "$_hp_f[chezmoi_ok]"
  fi

  echo -n "$_hp_f[e_chezmoi]"
}

function _hp_async_chezmoi {
  # We use some of the same mechanics as the VCS support, treating unapplied
  # changes without conflicts as "changed" and local changes as "unresolved".
  _hp_chezmoi=( active 0 )
  (( $_hp_conf[enable_chezmoi] && $+commands[chezmoi] )) || return;

  _hp_chezmoi[active]=1
  _hp_chezmoi[incoming]="$(chezmoi status | egrep '^ M' | wc -l)"
  _hp_chezmoi[outgoing]="$(chezmoi status | egrep '^MM' | wc -l)"

  typeset -p _hp_chezmoi
}
