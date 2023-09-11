## Asynchronous TaskWarrior processing ###################

typeset -A _hp_task

# Called only when we know _hp_task contains all the information we need.
function _hp_fmt_task_actual {
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

function _hp_fmt_task {
  if [[ ${_hp_task[status]} == "done" ]]; then
    _hp_fmt_task_actual
  elif [[ ${_hp_task[status]} == "sync" ]]; then
    echo -n "$_hp_f[s_task]$_hp_f[task_sync]$_hp_f[e_task]"
  fi
}

function _hp_async_task_collect {
  _hp_task=(
    "status" "done"
    "critical" "$(task rc.gc=0 rc.recurrence=0 "$_hp_conf[task_filter_critical]" count)"
    "urgent" "$(task rc.gc=0 rc.recurrence=0 "$_hp_conf[task_filter_urgent]" count)"
    "soon" "$(task rc.gc=0 rc.recurrence=0 "$_hp_conf[task_filter_soon]" count)"
  )
  typeset -p _hp_task
}

# "fast" taskwarrior -- query local task status and display it.
function _hp_async_task {
  if ! (( $_hp_conf[enable_task] && $+commands[task] )); then
    _hp_task=()
    typeset -p _hp_task
    return
  fi

  local taskd="$(task _get rc.taskd.server)"
  # If taskd is enabled, _async_taskx will do the thing instead.
  if [[ $taskd ]]; then
    _hp_task=(status "sync")
    typeset -p _hp_task
    return 0
  fi

  # Run "task next" to generate pending recurrences
  #task rc.gc=0 next &>/dev/null
  # And then collect the results
  _hp_async_task_collect
}

# "slow" taskwarrior -- run 'task sync' and then query local.
function _hp_async_taskx {
  # No need to clear _hp_task here because _hp_async_task will do it for us
  # if enable_task is off.
  (( $_hp_conf[enable_task] && $+commands[task] )) || return
  # Similarly, if the taskserver is not enabled, we just do nothing and let the
  # fast path handle it for us.
  local taskd="$(task _get rc.taskd.server)"
  [[ $taskd ]] || return 0
  # If it is enabled, the fast path does nothing at all and we need to do all
  # the work, including generating recurrences.
  #task rc.gc=0 next &>/dev/null
  # Then sync with the server and collect results.
  task rc.gc=0 rc.recurrence=0 sync &>/dev/null
  _hp_async_task_collect
}
