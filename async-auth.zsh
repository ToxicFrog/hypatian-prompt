
function _hp_async_sudo {
  typeset -g _hp_priv_sudo=0
  if (( $_hp_conf[enable_priv_sudo] )); then
    if sudo -n true 2>/dev/null; then
      _hp_priv_sudo=1
    fi
  fi
  typeset -p _hp_priv_sudo
}

function _hp_async_krb {
  typeset -g _hp_auth_krb=""
  if (( $_hp_conf[enable_auth_krb] )) && (( $+commands[klist] )); then
    if klist -s >/dev/null 2>&1; then
      _hp_auth_krb=1
    else
      _hp_auth_krb=0
    fi
  fi
  typeset -p _hp_auth_krb
}
