## Asynchronous Mercurial processing (slow and fast) ###################

function _hp_async_hg {
  typeset -gA _hp_hg=( active 0 )
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
  typeset -gA _hp_hgx=()
  if (( $_hp_conf[enable_vc_hg] )) && (( $+commands[hg] )) && _hp_search_up .hg >/dev/null; then
    _hp_hgx[incoming]="$(\hg --config 'alias.incoming = incoming' incoming --quiet 2>/dev/null | wc -l)"
    _hp_hgx[outgoing]="$(\hg --config 'alias.outgoing = outgoing' outgoing --quiet 2>/dev/null | wc -l)"
  fi
  typeset -p _hp_hgx
}
