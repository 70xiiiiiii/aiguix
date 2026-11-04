# Rules for adding packages to aiguix-nonfree

This branch is the nonfree channel of aiguix. What it is for is in the
[README](README.md).

The rules of aiguix apply here as well: see
[AGENTS.md on the branch `main`](https://github.com/70xiiiiiii/aiguix/blob/main/AGENTS.md).
This file lists only what is different.

## What belongs here

- Nonfree software only: software under a nonfree license, and binaries
  without public source code or without a public toolchain to build them.
  Anything that can be built from free source goes to `main`.
- Keep the nonfree part small. If only part of a package is nonfree, the
  free part goes to `main` and the package here builds on it.
- A package states its license exactly. For a nonfree license, use
  `license:nonfree` with the URL of the license text.
- A package says in its description which parts are nonfree and why.

## Layout

- Modules live in `aiguix-nonfree/packages/<topic>.scm` as
  `(aiguix-nonfree packages <topic>)`.
- Packages here may build on packages of aiguix. Nothing on `main` may
  depend on this branch: aiguix must work without it.

## Checking a package

Run the checks from a checkout of this branch, with a checkout of `main`
on the load path as well:

```sh
guix build -L . -L <path-to-main> <package>
guix lint -L . -L <path-to-main> <package>
guix style -L . -L <path-to-main> <package>
```

## Commits and pushes

- Messages start with `aiguix-nonfree:`, for example
  `aiguix-nonfree: Add <name>.`
- Compare against `origin/nonfree`, not `origin/main`: fold corrections
  with `git rebase -i --autosquash origin/nonfree`, and a human reads
  them with `git log -p origin/nonfree..` before pushing.
- Never merge `main` into this branch or this branch into `main`. They
  share no history.
