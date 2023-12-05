# .my-bash-environment

My configs to easily download and use on new machines.

## Install

1. Install `curl`;
2. Execute:

    ```bash
    source <(curl https://raw.githubusercontent.com/Nikolai2038/.my-bash-environment/main/main.sh)
    ```

## Update

Script will autoupdate itself.

If you don't want this, change (add):

```bash
source "${HOME}/.my-bash-environment/main.sh"
```

to

```bash
DISABLE_BASH_ENVIRONMENT_AUTOUPDATE=1
source "${HOME}/.my-bash-environment/main.sh"
```

in your `.bashrc`.
