## Asynchronous TaskWarrior processing ###################

typeset -A _hp_task

function _hp_fmt_task {
  (( ${_hp_task[active]:-0} )) || {
    echo -n "⁇"
  }
  echo -n "$_hp_f[s_task]"
  if (( _hp_task[critical] )); then
    echo -n "$_hp_f[task_critical]$((_hp_task[critical]+_hp_task[urgent]))"
  elif (( _hp_task[urgent] )); then
    echo -n "$_hp_f[task_urgent]$_hp_task[urgent]"
  elif (( _hp_task[soon] )); then
    echo -n "$_hp_f[task_soon]$_hp_task[soon]"
  else
    echo -n "$_hp_f[task_alldone]"
  fi
  echo -n "$_hp_f[e_task]"
}

function _hp_async_task {
  _hp_task=( active 0 )
  # Run "task next" to generate pending recurrences
  task rc.gc=0 next &>/dev/null
  (( $_hp_conf[enable_task] && $+commands[task] )) || return
  _hp_task=(
    "active" 1
    "critical" "$(task rc.gc=0 "$_hp_conf[task_filter_critical]" count)"
    "urgent" "$(task rc.gc=0 "$_hp_conf[task_filter_urgent]" count)"
    "soon" "$(task rc.gc=0 "$_hp_conf[task_filter_soon]" count)"
  )
  typeset -p _hp_task
}
