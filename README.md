# .my-bash-environment

My configs to easily download and use on new machines.

## Install configs

1. Install `curl`;
2. Execute:

    ```bash
    mkdir --parents "${HOME}/.my-bash-environment" && \
    curl https://raw.githubusercontent.com/Nikolai2038/.my-bash-environment/main/main.sh > "${HOME}/.my-bash-environment/main.sh" && \
    source "${HOME}/.my-bash-environment/main.sh" && \
    echo 'source "${HOME}/.my-bash-environment/main.sh"' >> ~/.bashrc
    ```

## Update configs

Execute:

```bash
curl https://raw.githubusercontent.com/Nikolai2038/.my-bash-environment/main/main.sh > "${HOME}/.my-bash-environment/main.sh" && \
source "${HOME}/.my-bash-environment/main.sh"
```
