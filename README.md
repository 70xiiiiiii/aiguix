# aiguix

A [GNU Guix](https://guix.gnu.org/) channel for packages written by or with
AI.

Every package here was written by or with an AI model. Each one builds and
passes its tests, but it has not been reviewed the way Guix reviews its own
packages. Use it the way you would use any third-party channel: read what
you install.

## Rules

1. **Free software only.** Every package must be free software, as in
   Guix. Nonfree software belongs on the branch
   [`nonfree`](https://github.com/70xiiiiiii/aiguix/tree/nonfree), a
   separate channel that builds on this one.
2. **Written by or with AI, and marked as such.** Every commit carries a
   `Co-Authored-By:` trailer that names the model involved, for example:

   ```
   Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
   ```

3. **Built and tested.** A package is committed only after `guix build`
   succeeds, its test suite passes, and `guix lint` reports no errors.
4. **Guix conventions.** Commit messages, code style and line length follow
   the [Guix manual](https://guix.gnu.org/manual/en/html_node/Submitting-Patches.html).
5. **Upstream first.** A package is removed from this channel once Guix
   has a compatible version.

## Usage

Add the channel to `~/.config/guix/channels.scm`:

```scheme
(cons (channel
        (name 'aiguix)
        (url "https://github.com/70xiiiiiii/aiguix")
        (branch "main"))
      %default-channels)
```

Then run `guix pull`.

To get the nonfree part as well, add the channel of the branch `nonfree`
instead, as its
[README](https://github.com/70xiiiiiii/aiguix/blob/nonfree/README.md)
shows. It brings this channel along.

The channel has no
[introduction](https://guix.gnu.org/manual/en/html_node/Channel-Authentication.html)
yet, so `guix pull` cannot authenticate its commits and will warn about it.

## License

GPL-3.0-or-later, like GNU Guix. See [LICENSE](LICENSE).
