# .my-bash-environment

My configs to easily download and use on new machines.

## Install

1. Install `curl`:

   ```bash
   sudo apt update && sudo apt install -y curl
   ```

2. Execute:

    ```bash
    source <(curl https://raw.githubusercontent.com/Nikolai2038/.my-bash-environment/main/main.sh)
    ```

## Update

Script will autoupdate itself. You can disable it via env-variables (see below).

## Settings

You can change script's behaviour via env-variables:

- `N2038_DISABLE_BASH_ENVIRONMENT_AUTOUPDATE` - if set, will disable autoupdate (default: empty);
- `N2038_DISABLE_BASH_ENVIRONMENT_CLEAR` - if set, will disable `clear` after shell creates (default: empty).

You should set their values in your `.bashrc` file. Example:

```bash
N2038_DISABLE_BASH_ENVIRONMENT_AUTOUPDATE=1
source "${HOME}/.my-bash-environment/main.sh"
```
