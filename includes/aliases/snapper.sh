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
if [ -z "${BY_HAND_PREFIX}" ]; then
  BY_HAND_PREFIX="BY HAND: "
fi

# Creates a snapshots with specified comment for specified Snapper config
_n2038_snapper_create_snapshot() {
  local prefix="${1}" && { shift || true; }
  local config="${1}" && { shift || true; }
  local description="${1}" && { shift || true; }
  if [ -z "${prefix}" ] || [ -z "${config}" ] || [ -z "${description}" ]; then
    echo "Usage: _n2038_snapper_create_snapshot <prefix> <config name> <description>" >&2
    return 1
  fi

  # shellcheck disable=SC2086
  ${sudo_prefix}snapper -c "${config}" create --description "${prefix}${description}" --userdata "tag=${SNAPPER_USERDATA_TAG}" || return "$?"

  return 0
}

# Delete a snapshot with specified ID for specified Snapper config
_n2038_snapper_delete_snapshot() {
  local config="${1}" && { shift || true; }
  local snapshot_id="${1}" && { shift || true; }
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
  local prefix="${1}" && { shift || true; }
  local info="${1}" && { shift || true; }
  if [ -z "${prefix}" ] || [ -z "${info}" ]; then
    echo "Usage: _n2038_snapper_create_snapshots_for_all_configs <prefix> <description>" >&2
    return 1
  fi

  # Get configs as list
  local configs_list
  configs_list="$(n2038_snapper_list_configs)"

  # Convert to array
  declare -a configs
  mapfile -t configs <<< "${configs_list}" || exit "$?"

  # Create snapshot for each config
  local config
  for config in "${configs[@]}"; do
    _n2038_snapper_create_snapshot "${prefix}" "${config}" "${info}"
  done

  return 0
}

# Print snapshot id for specified config and description with n2038_number
_n2038_snapper_echo_snapshot_id_for_config() {
  local config="${1}" && { shift || true; }
  local n2038_number="${1}" && { shift || true; }
  if [ -z "${config}" ] || [ -z "${n2038_number}" ]; then
    echo "Usage: _n2038_snapper_echo_snapshot_id_for_config <config> <n2038_number>" >&2
    return 1
  fi

  local snapshot_id
  # shellcheck disable=SC2086
  snapshot_id="$(${sudo_prefix}snapper -c "${config}" list --columns userdata,number | sed -En "s/^tag=${SNAPPER_USERDATA_TAG}\\s*[\\|│]\\s*([0-9]+)\\s*\$/\\1/p" | head -n "${n2038_number}" | tail -n 1)" || return "$?"

  if [ -z "${snapshot_id}" ]; then
    echo "Snapshot not found!" >&2
    return 1
  fi

  echo "${snapshot_id}"

  return 0
}

# Print snapshot description for specified config and description with n2038_number
_n2038_snapper_echo_snapshot_description_for_config() {
  local config="${1}" && { shift || true; }
  local n2038_number="${1}" && { shift || true; }
  if [ -z "${config}" ] || [ -z "${n2038_number}" ]; then
    echo "Usage: _n2038_snapper_echo_snapshot_id_for_config <config> <n2038_number>" >&2
    return 1
  fi

  local snapshot_description
  # shellcheck disable=SC2086
  snapshot_description="$(${sudo_prefix}snapper -c "${config}" list --columns userdata,description | sed -En "s/^tag=${SNAPPER_USERDATA_TAG}\\s*[\\|│]\\s*(.+)\\s*\$/\\1/p" | head -n "${n2038_number}" | tail -n 1)" || return "$?"

  if [ -z "${snapshot_description}" ]; then
    echo "Snapshot not found!" >&2
    return 1
  fi

  echo "${snapshot_description}"

  return 0
}

# Print a list of keyword snapshots with n2038_number value
n2038_snapper_list() {
  if ! bat --help > /dev/null 2>&1; then
    echo "Snapper is not installed!" >&2
    return 1
  fi

  local column_name_1="${SNAPPER_USERDATA_TAG}_number"
  # Use sudo here to get password before any output
  # shellcheck disable=SC2086
  ${sudo_prefix}echo "============================================================"
  echo "${column_name_1} │ date                │ description"
  echo "============================================================"

  # "nl" to print line numbers
  # shellcheck disable=SC2086
  ${sudo_prefix}snapper -c "rootfs" --iso list --columns userdata,date,description \
    | sed -En "s/tag=${SNAPPER_USERDATA_TAG}\\s*[\\|│] (.*)\$/\1/p" \
    | nl --number-width="${#column_name_1}" --number-separator=" │ " \
    || return "$?"

  echo "============================================================"

  return 0
}

# Print a list of all snapshots of specified Snapper config
n2038_snapper_list_all() {
  if ! bat --help > /dev/null 2>&1; then
    echo "Snapper is not installed!" >&2
    return 1
  fi

  local config="${1}" && { shift || true; }
  if [ -z "${config}" ]; then
    echo "Usage: n2038_snapper_list_all <config name>" >&2
    return 1
  fi

  # shellcheck disable=SC2086
  ${sudo_prefix}snapper -c "${config}" --iso list --columns number,type,cleanup,date,description,userdata || return "$?"

  return 0
}

# Print a list of existing Snapper configs
n2038_snapper_list_configs() {
  if ! bat --help > /dev/null 2>&1; then
    echo "Snapper is not installed!" >&2
    return 1
  fi

  ll /etc/snapper/configs || return "$?"
  return 0
}

# Creates snapshots for main Snapper configs (which for me are: "rootfs", "home" and "root")
n2038_snapper_create_with_description() {
  if ! bat --help > /dev/null 2>&1; then
    echo "Snapper is not installed!" >&2
    return 1
  fi

  local description="${1}" && { shift || true; }
  if [ -z "${description}" ]; then
    echo "Usage: n2038_snapper_create_with_description <description> [prefix=\"${BY_HAND_PREFIX}\"]" >&2
    return 1
  fi
  local prefix="${1:-${BY_HAND_PREFIX}}" && { shift || true; }

  # Configs to use
  declare -a configs=(
    "rootfs"
    "home"
    "root"
  )

  # Create snapshot for each config
  for config in "${configs[@]}"; do
    _n2038_snapper_create_snapshot "${prefix}" "${config}" "${description}" || return "$?"
  done

  return 0
}

# Apply the specified snapshots for main Snapper configs (which for me are: "rootfs", "home" and "root")
# shellcheck disable=SC2086
n2038_snapper_goto_n2038_number() {
  if ! bat --help > /dev/null 2>&1; then
    echo "Snapper is not installed!" >&2
    return 1
  fi

  local n2038_number="${1}" && { shift || true; }
  if [ -z "${n2038_number}" ]; then
    echo "Usage: n2038_snapper_goto_n2038_number <n2038_number>" >&2
    return 1
  fi

  # Clear old backups
  if [ -e "${HOME_PARTITION_MOUNT_POINT}/@home_old" ]; then
    ${sudo_prefix}rm -Rf "${HOME_PARTITION_MOUNT_POINT}/@home_old" || return "$?"
  fi
  if [ -e "${HOME_PARTITION_MOUNT_POINT}/@root_old" ]; then
    ${sudo_prefix}rm -Rf "${HOME_PARTITION_MOUNT_POINT}/@root_old" || return "$?"
  fi

  local snapshot_description
  snapshot_description="$(_n2038_snapper_echo_snapshot_description_for_config "home" "${n2038_number}" "${SNAPPER_USERDATA_TAG}")" || return "$?"

  local snapshot_id_for_home
  snapshot_id_for_home="$(_n2038_snapper_echo_snapshot_id_for_config "home" "${n2038_number}" "${SNAPPER_USERDATA_TAG}")" || return "$?"

  local snapshot_id_for_root
  snapshot_id_for_root="$(_n2038_snapper_echo_snapshot_id_for_config "root" "${n2038_number}" "${SNAPPER_USERDATA_TAG}")" || return "$?"

  # We pass empty string for second argument to not add prefix
  n2038_snapper_create_with_description "Auto-backup before restoring to #${n2038_number} \"${snapshot_description//"${BY_HAND_PREFIX}"/}\"" "" || return "$?"
  # Because we created snapshots right now, we must increase n2038_number by 1
  ((n2038_number++))

  # home
  ${sudo_prefix}mv --no-target-directory "${HOME_PARTITION_MOUNT_POINT}/@home" "${HOME_PARTITION_MOUNT_POINT}/@home_old" || return "$?"
  ${sudo_prefix}btrfs subvolume snapshot "${HOME_PARTITION_MOUNT_POINT}/@home-snapshots/${snapshot_id_for_home}/snapshot" "${HOME_PARTITION_MOUNT_POINT}/@home" || {
    # Discard changes
    ${sudo_prefix}mv --no-target-directory "${HOME_PARTITION_MOUNT_POINT}/@home_old" "${HOME_PARTITION_MOUNT_POINT}/@home" || return "$?"

    return "$?"
  }

  # root
  ${sudo_prefix}mv --no-target-directory "${HOME_PARTITION_MOUNT_POINT}/@root" "${HOME_PARTITION_MOUNT_POINT}/@root_old" || return "$?"
  ${sudo_prefix}btrfs subvolume snapshot "${HOME_PARTITION_MOUNT_POINT}/@root-snapshots/${snapshot_id_for_root}/snapshot" "${HOME_PARTITION_MOUNT_POINT}/@root" || {
    # Discard changes
    ${sudo_prefix}mv --no-target-directory "${HOME_PARTITION_MOUNT_POINT}/@root_old" "${HOME_PARTITION_MOUNT_POINT}/@root" || return "$?"

    return "$?"
  }

  # rootfs
  local snapshot_id_for_rootfs
  snapshot_id_for_rootfs="$(_n2038_snapper_echo_snapshot_id_for_config "rootfs" "${n2038_number}" "${description}")"
  echo CONFIRM | ${sudo_prefix}snapper-rollback "${snapshot_id_for_rootfs}" || return "$?"

  ${sudo_prefix}reboot || return "$?"

  return 0
}

# ----------------------------------------
