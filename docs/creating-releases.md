# Creating releases

`CHANGELOG.md` is the only changelog a person edits. `debian/changelog` and the RPM `%changelog` are generated from it.

Agents must not run `scripts/release.sh`. The script refuses `CURSOR_AGENT=1`. Do not unset that, tag, or push a release tag instead.

## How it works

The [Release](../.github/workflows/release.yml) workflow runs when:

- a tag matching `v*` is pushed (run `./scripts/release.sh` — humans only; `v*-packages` is ignored), or
- **Release** is started manually from the GitHub Actions UI (`workflow_dispatch`).

To build one package family without publishing, run the matching workflow on your branch:

| Actions name | File | Command |
| --- | --- | --- |
| **Release - Debian** | [`release-debian.yml`](../.github/workflows/release-debian.yml) | `gh workflow run release-debian.yml --ref <branch>` |
| **Release - Fedora** | [`release-fedora.yml`](../.github/workflows/release-fedora.yml) | `gh workflow run release-fedora.yml --ref <branch>` |

Ignore anything named **X - …**. Those are the jobs Release calls.

On a tag push, CI checks `scripts/release/changelog.sh version` against the tag with the leading `v` removed, then `sync-debian-changelog.sh` fills `debian/changelog` and the RPM `%changelog` in the CI checkout. A hyphen in the version becomes `~` (`1.2.5-alpha` → Debian `1.2.5~alpha-1`). The `.deb` and `.rpm` are published on a GitHub Release named `${tag}-packages`. The version tag Release is the notes for that version.

If that workflow succeeds, `finalize-changelog.sh` stamps the date on the version heading, adds a fresh `[Unreleased]`, and commits `CHANGELOG.md` to `main`. It does not commit `debian/changelog`. A manual run syncs and builds. It does not finalize and it does not publish.

## Changelog

While working, add bullets under `## [Unreleased]`. When the release is ready, rename that heading to the version, for example `## [0.1.0] - Unreleased`.

Regenerate packaging locally with:

```bash
./scripts/release/sync-debian-changelog.sh
```

## Making a release

1. Finish the release on `main`. Commit everything that should ship.
2. Update `CHANGELOG.md`. Put the notes under `## [0.1.0] - Unreleased` (the version in the heading).
3. Run the human-only release script:

   ```bash
   ./scripts/release.sh
   ```

   It checks a clean tree, refuses empty notes, creates an annotated `v0.1.0` tag, and pushes the branch plus the tag.

   If CI failed for that version, commit the fix, then:

   ```bash
   ./scripts/release.sh --retry
   ```

   That deletes the local and origin version tag and the matching `v*-packages` tag, then tags HEAD and pushes again.

4. Watch **Actions → Release**. Debian and Fedora both have to finish before Publish. Publish creates `${tag}-packages` with the `.deb` and `.rpm`, then the version-tag notes. Finalize runs only after Publish succeeds.

## Manual builds

**Actions → Release - Debian** or **Release - Fedora → Run workflow** rebuilds that family and uploads artifacts on the run. **Actions → Release → Run workflow** builds both and does not publish.
