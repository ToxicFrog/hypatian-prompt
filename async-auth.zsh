## Asynchronous privilege checking -- sudo and kerberos ################

typeset _hp_priv_sudo=0 _hp_auth_krb=""

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
