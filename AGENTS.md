# Rules for adding packages to aiguix

These rules are for anyone who adds packages here: AI agents and the
humans who work with them. What the channel is for is in the
[README](README.md).

## What belongs here

- Free software only. Nonfree software goes to
  [nonguix](https://gitlab.com/nonguix/nonguix).
- Packages written by or with AI.
- A package leaves this channel once Guix has a compatible version.

## Writing a package

1. **Package dependencies separately.** A dependency that is its own
   upstream project becomes its own package; do not bundle it. Code may
   stay bundled only if it is a fork with project-specific patches or has
   no upstream of its own. Say why in the commit message.
2. **Use what Guix has.** Take the Guix package if it exists. A newer
   version than the one upstream asks for is fine if the build and the
   tests pass with it.
3. **No version variants.** Do not add `foo-1.22` next to `foo` just for
   one package. If the Guix version is too old, define the newer version
   here by inheriting from the Guix package, and offer the update to Guix.
4. **Change sources in the package definition.** Use `substitute*` in a
   build phase or a `snippet` in the `origin`. No patch files. A build
   file that replaces the upstream build system (for example CMake instead
   of Bazel) goes into `aux-files/<package>/`. Say why in the commit
   message.
5. **Keep single-use things inside the package.** A source used by one
   package only is an `origin` inside it, not a separate definition.
   Avoid helper variables.
6. **Gexp style.** A `let` used only inside a gexp goes inside the
   `#~(...)`. Use `#$` once, where the name is bound, then use the plain
   name:

   ```scheme
   #~(let ((lld #$(this-package-native-input "lld")))
       (string-append "-fuse-ld=" lld "/bin/ld.lld"))
   ```

## Layout

- Modules live in `aiguix/packages/<topic>.scm` as
  `(aiguix packages <topic>)`.
- Within a module, a package that the others build on comes first (for
  example `xlibre-server`); the rest are sorted by name.
- The file `.guix-channel` marks the repository as a channel.

## Checking a package

Run these in the repository root before you commit:

```sh
guix build -L . <package>
guix lint -L . <package>
guix style -L . <package>
```

- The build succeeds and the test suite passes. Disabling a test needs a
  reason in the commit message.
- `guix lint` shows no errors. If it fails because of the network, use
  `guix lint -L . -x cve,archival <package>`.
- Lines are at most 78 characters. If `guix style` makes a line longer,
  format it by hand.

## Commits and pushes

- **One commit, one definition, as in Guix.** A commit adds or changes
  exactly one `define` or `define-public`. It also carries the files that
  belong to that package, and nothing else: a new module file comes with
  its first definition, and a package comes with its patch, its file in
  `aux-files/<package>/` and its crates.
- **Rust crates.** The crates of a Rust package live in
  `aiguix/packages/rust-crates.scm`, as in Guix. The commit that adds or
  updates the package also adds the crates it needs and its entry in
  `lookup-cargo-inputs` there. Generate both from the package's
  `Cargo.lock`:

  ```sh
  guix import crate --lockfile=Cargo.lock <package> \
    --insert=aiguix/packages/rust-crates.scm
  ```

  The package takes them with
  `(cargo-inputs '<package> #:module '(aiguix packages rust-crates))`.
- **A push may hold a series.** Several such commits can go out in one
  push, as in Guix. Dependencies come first, and every commit in the
  series builds on its own.
- **Messages in Guix style:**

  ```
  aiguix: Add xlibre-server.

  * aiguix/packages/xlibre.scm (xlibre-server): New variable.

  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
  ```

  For an update: `aiguix: <name>: Update to <version>.` For other
  changes: `aiguix: <name>: <what changed>.`
- **Always add the trailer.** `Co-Authored-By:` names the AI model that
  took part.
- **Fix before pushing, never after.** Before the push, fold a correction
  into the commit it belongs to: `git commit --amend` for the last one,
  otherwise `git commit --fixup <commit>` and
  `git rebase -i --autosquash origin/main`. Pushed commits are never
  rewritten: no rebase, no force push, no merge commits.
- **A human pushes.** An agent prepares the commits; a human reads them
  with `git log -p origin/main..` and pushes them.
