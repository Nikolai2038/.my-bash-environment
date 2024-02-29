# .my-bash-environment

My configs to easily download and use on new machines.

## Install

1. Make sure `curl` and `git` are installed:

   ```bash
   sudo apt-get update && sudo apt-get install -y curl git
   ```

2. Execute:

    ```bash
   git clone https://github.com/Nikolai2038/.my-bash-environment.git && \
   rm -rf ./.my-bash-environment/.git && \
   source ./.my-bash-environment/main.sh
    ```

## Update

Script will autoupdate itself. You can disable it via env-variables (see below).

## Settings

You can change script's behaviour via env-variables:

- `N2038_DISABLE_BASH_ENVIRONMENT_AUTOUPDATE` - if equals to `1`, will disable autoupdate (default: `0`);
- `N2038_DISABLE_BASH_ENVIRONMENT_CLEAR` - if equals to `1`, will disable `clear` after shell creates (default: `1`);
- `N2038_DISABLE_BASH_ENVIRONMENT_MESSAGES` - if equals to `1`, will disable some messages on new shell created (default: `1`).

You should set their values in your `.bashrc` file. Example:

```bash
N2038_DISABLE_BASH_ENVIRONMENT_AUTOUPDATE=1
source "${HOME}/.my-bash-environment/main.sh"
```
