# What is this?

Small project to run extenddb in place without installing globally and poluting your machine

> **Caution:** before running, ExtenDB has to be built (this includes dependecies fetching and compilation) and may take a few minutes on the first run!

# To start:

```sh
$ make -B
```

# Dependecies:

- curl
- git
- jq
- rust + cargo (install with `curl -sSf https://sh.rustup.rs/ | sh`)

# Environment variables:

To get the copy/paste variant of the environment variables, run:

```sh
$ make -B env
```

To populate the environment variables (Linux and MacOS):

```sh
$ eval $(make -B env)
```

To cleanup the environment from environment variables (not necessary but useful, env vars are local to the current session):

```sh
$ unset $(env | grep '^AWS_' | cut -d= -f1)
```
