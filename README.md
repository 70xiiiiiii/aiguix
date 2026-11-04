# aiguix-nonfree

**This branch contains nonfree software.** It is a separate
[GNU Guix](https://guix.gnu.org/) channel for what
[aiguix](https://github.com/70xiiiiiii/aiguix) does not accept: software
under a nonfree license, and prebuilt binaries whose source code or
toolchain is not public. Each package states its license and which of its
parts are nonfree.

The channel builds on aiguix. Everything else, what aiguix is and its
rules, is in the
[README on the branch `main`](https://github.com/70xiiiiiii/aiguix/blob/main/README.md).

## Usage

Add this channel to `~/.config/guix/channels.scm` and run `guix pull`.
aiguix comes along as a dependency:

```scheme
(cons (channel
        (name 'aiguix-nonfree)
        (url "https://github.com/70xiiiiiii/aiguix")
        (branch "nonfree"))
      %default-channels)
```

To pin aiguix yourself, also list its channel; your entry takes
precedence over the dependency.

## License

The package definitions are under GPL-3.0-or-later, like GNU Guix. See
[LICENSE](LICENSE). The software they install keeps its own license.
