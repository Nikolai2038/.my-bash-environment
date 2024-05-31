#!/bin/bash

# ----------------------------------------
# Snapper aliases
# ----------------------------------------

if [ -z "${SNAPPER_USERDATA_TAG}" ]; then
  SNAPPER_USERDATA_TAG="n2038"
fi
if [ -z "${HOME_PARTITION_MOUNT_POINT}" ]; then
  HOME_PARTITION_MOUNT_POINT="/mnt/partition-for-data"
fi

# Print a list of existing Snapper configs
_n2038_snapper_list_configs() {
  ll /etc/snapper/configs || return "$?"
  return 0
}

# Print a list of all snapshots of specified Snapper config
_n2038_snapper_list_snapshots_all() {
  config="${1}" && { shift || true; }
  if [ -z "${config}" ]; then
    echo "Usage: _n2038_snapper_list_snapshots_all <config name>" >&2
    return 1
  fi

  # shellcheck disable=SC2086
  ${sudo_prefix}snapper -c "${config}" --iso list --columns number,type,cleanup,date,description,userdata || return "$?"

  return 0
}

# Print a list of keyword snapshots with offset value
n2038_snapper_list() {
  if ! bat --help > /dev/null 2>&1; then
    echo "Snapper is not installed!" >&2
    return 1
  fi

  local column_name_1="offset"
  local column_name_2="description"
  echo "========================================"
  echo "${column_name_1} | ${column_name_2}"
  echo "========================================"

  # "nl" to print line numbers (for "offset variable")
  # "tac" for reverse order
  # shellcheck disable=SC2086
  ${sudo_prefix}snapper -c "rootfs" --iso list --type single --columns userdata,description | sed -En "s/tag=${SNAPPER_USERDATA_TAG}\\s*[\\|│] (.*)\$/\1/p" \
    | nl --number-width="${#column_name_1}" --number-separator=" | " \
    || return "$?"

  echo "========================================"

  return 0
}

# Creates a snapshots with specified comment for specified Snapper config
_n2038_snapper_create_snapshot() {
  config="${1}" && { shift || true; }
  description="${1}" && { shift || true; }
  if [ -z "${config}" ] || [ -z "${description}" ]; then
    echo "Usage: _n2038_snapper_create_snapshot <config name> <info (description)>" >&2
    return 1
  fi

  # shellcheck disable=SC2086
  ${sudo_prefix}snapper -c "${config}" create --description "${description}" --userdata "tag='${SNAPPER_USERDATA_TAG}'" || return "$?"

  return 0
}

# Delete a snapshot with specified ID for specified Snapper config
_n2038_snapper_delete_snapshot() {
  config="${1}" && { shift || true; }
  snapshot_id="${1}" && { shift || true; }
  if [ -z "${config}" ] || [ -z "${snapshot_id}" ]; then
    echo "Usage: _n2038_snapper_delete_snapshot <config name> <snapshot_id>" >&2
    return 1
  fi

  # shellcheck disable=SC2086
  ${sudo_prefix}snapper -c "${config}" delete "${snapshot_id}" || return "$?"

  return 0
}

# Creates snapshots for all Snapper configs
_n2038_snapper_create_snapshots_for_all_configs() {
  local info="${1}" && { shift || true; }
  if [ -z "${info}" ]; then
    echo "Usage: _n2038_snapper_create_snapshots_for_all_configs <info (description)>" >&2
    return 1
  fi

  # Get configs as list
  local configs_list
  configs_list="$(_n2038_snapper_list_configs)"

  # Convert to array
  declare -a configs
  mapfile -t configs <<< "${configs_list}" || exit "$?"

  # Create snapshot for each config
  local config
  for config in "${configs[@]}"; do
    _n2038_snapper_create_snapshot "${config}" "${info}"
  done

  return 0
}

# Creates snapshots for main Snapper configs (which for me are: "rootfs", "home" and "root")
n2038_snapper_create_with_info() {
  if ! bat --help > /dev/null 2>&1; then
    echo "Snapper is not installed!" >&2
    return 1
  fi

  local info="${1}" && { shift || true; }
  if [ -z "${info}" ]; then
    echo "Usage: n2038_snapper_create_with_info <info (description)>" >&2
    return 1
  fi

  # Configs to use
  declare -a configs=(
    "rootfs"
    "home"
    "root"
  )

  # Create snapshot for each config
  for config in "${configs[@]}"; do
    _n2038_snapper_create_snapshot "${config}" "${info}"
  done

  return 0
}

# Print snapshot id for specified config and description with offset (default = 1 - the last snapshot by criteria)
_n2038_snapper_echo_snapshot_id_for_config() {
  local config="${1}" && { shift || true; }
  local offset="${1}" && { shift || true; }
  if [ -z "${config}" ] || [ -z "${offset}" ]; then
    echo "Usage: _n2038_snapper_echo_snapshot_id_for_config <config> <offset> [description=nikolai2038]" >&2
    return 1
  fi
  local description="${1:-${SNAPPER_USERDATA_TAG}}" && { shift || true; }

  local snapshot_id
  # shellcheck disable=SC2086
  snapshot_id="$(${sudo_prefix}snapper -c "${config}" list --columns description,number | sed -En "s/^${description}\\s*[\\|│]\\s*([0-9]+)\\s*\$/\\1/p" | tail -n "${offset}" | head -n 1)" || return "$?"

  if [ -z "${snapshot_id}" ]; then
    echo "Snapshot number not found!" >&2
    return 1
  fi

  echo "${snapshot_id}"

  return 0
}

# Apply the specified snapshots for main Snapper configs (which for me are: "rootfs", "home" and "root")
# shellcheck disable=SC2086
n2038_snapper_goto_offset() {
  if ! bat --help > /dev/null 2>&1; then
    echo "Snapper is not installed!" >&2
    return 1
  fi

  local offset="${1}" && { shift || true; }
  if [ -z "${offset}" ]; then
    echo "Usage: n2038_snapper_goto_offset <offset> [description=nikolai2038]" >&2
    return 1
  fi

  # Clear old backups
  if [ -e "${HOME_PARTITION_MOUNT_POINT}/@home_old" ]; then
    ${sudo_prefix}rm -Rf "${HOME_PARTITION_MOUNT_POINT}/@home_old"
  fi
  if [ -e "${HOME_PARTITION_MOUNT_POINT}/@root_old" ]; then
    ${sudo_prefix}rm -Rf "${HOME_PARTITION_MOUNT_POINT}/@root_old"
  fi

  n2038_snapper_create_with_info "Auto-backup before restoring" || return "$?"
  # Because we created snapshots right now, we must increase offset by 1
  ((offset++))

  # home
  ${sudo_prefix}mv --no-target-directory "${HOME_PARTITION_MOUNT_POINT}/@home" "${HOME_PARTITION_MOUNT_POINT}/@home_old" || return "$?"
  local snapshot_id_for_home
  snapshot_id_for_home="$(_n2038_snapper_echo_snapshot_id_for_config "home" "${offset}" "${SNAPPER_USERDATA_TAG}")"
  ${sudo_prefix}btrfs subvolume snapshot "${HOME_PARTITION_MOUNT_POINT}/@home-snapshots/${snapshot_id_for_home}/snapshot" "${HOME_PARTITION_MOUNT_POINT}/@home" || {
    # Discard changes
    ${sudo_prefix}mv --no-target-directory "${HOME_PARTITION_MOUNT_POINT}/@home_old" "${HOME_PARTITION_MOUNT_POINT}/@home" || return "$?"

    return "$?"
  }

  # root
  ${sudo_prefix}mv --no-target-directory "${HOME_PARTITION_MOUNT_POINT}/@root" "${HOME_PARTITION_MOUNT_POINT}/@root_old" || return "$?"
  local snapshot_id_for_root
  snapshot_id_for_root="$(_n2038_snapper_echo_snapshot_id_for_config "root" "${offset}" "${SNAPPER_USERDATA_TAG}")"
  ${sudo_prefix}btrfs subvolume snapshot "${HOME_PARTITION_MOUNT_POINT}/@root-snapshots/${snapshot_id_for_root}/snapshot" "${HOME_PARTITION_MOUNT_POINT}/@root" || {
    # Discard changes
    ${sudo_prefix}mv --no-target-directory "${HOME_PARTITION_MOUNT_POINT}/@root_old" "${HOME_PARTITION_MOUNT_POINT}/@root" || return "$?"

    return "$?"
  }

  # rootfs
  local snapshot_id_for_rootfs
  snapshot_id_for_rootfs="$(_n2038_snapper_echo_snapshot_id_for_config "rootfs" "${offset}" "${description}")"
  echo CONFIRM | ${sudo_prefix}snapper-rollback "${snapshot_id_for_rootfs}" || return "$?"

  ${sudo_prefix}reboot || return "$?"

  return 0
}

# ----------------------------------------
