#!/bin/bash

# ----------------------------------------
# GIT aliases
# ----------------------------------------
alias gs="git status"
# TODO: In development
# git log --graph --pretty=format:"%Cgreen%h %Cblue%an %Cgreen%ad %Creset%s %S" --date=format:"%Y-%m-%d %H:%M:%S"
# git log --pretty=format:"%h%x09%an%x09%ad%x09%s"
alias gl="git log --graph --oneline --decorate"
alias ga="git add ."
alias gc="git commit -m"
alias gac="ga && gc"
alias gpush="git push"
alias gpull="git pull"
# ----------------------------------------
