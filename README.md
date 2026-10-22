# gh-accounts

Work with several GitHub accounts on one Mac (personal + one per client) without ever running `gh auth switch`.

The account is picked **by folder**. Anything that runs `gh` or `git` inside a client folder — you, Claude Code, Codex, Cursor — automatically uses that client's account, SSH key, commit identity and GPG key.

```
~/Sites/ACME/api      → gh: acme-user   · git: You <you@acme.com>   · ssh: github-acme
~/Sites/GLOBEX/web    → gh: globex-user · git: You <you@globex.io>  · ssh: github-globex
anywhere else         → your personal account
```

## Install

Homebrew:

```bash
brew install aiherrera/tap/gh-accounts
```

Or as a GitHub CLI extension (run it as `gh accounts …`):

```bash
gh extension install aiherrera/gh-accounts
```

Then, once:

```bash
gh-accounts init     # installs the gh wrapper and imports existing includeIf setups
gh-accounts doctor
```

For signed commits: `brew install gnupg pinentry-mac`.

## Add a client

```bash
gh-accounts add
```

It asks for a slug, folder, the client's GitHub user, commit email and orgs, then:

1. Logs that account into `gh` (browser) **without** changing your active account
2. Creates an SSH key, a `Host github-<slug>` alias and uploads the key
3. Creates and uploads a GPG signing key (optional)
4. Adds an `includeIf` in `~/.gitconfig` for the commit identity
5. Adds `insteadOf` rules so `git@github.com:<org>/…` and `https://github.com/<org>/…` use the client's key
6. Updates the rules for AI agents

## Commands

| Command | What it does |
|---|---|
| `init` | Install/refresh the wrapper, registry and AI rules |
| `add` | Add or update a client |
| `remove <slug>` | Remove a client (keys and repos are kept) |
| `import` | Import clients from existing `includeIf` rules |
| `list` | List registered accounts |
| `which` | Show the account/identity for the current folder |
| `doctor` | Check token, SSH and git identity for every client |
| `sync` | Regenerate the AI rules |

## How it works

- **Registry** — `~/.config/gh-accounts/accounts.tsv`, one line per client. Your clients never live in this repo.
- **gh wrapper** — `~/.local/bin/gh` matches `$PWD` against the registry and sets `GH_TOKEN` from `gh auth token --user <account>`, then calls the real `gh`. `gh auth …` passes through untouched. It is put first in `PATH` via `~/.zshenv`, so non-interactive shells used by AI agents get it too.
- **git** — `includeIf "gitdir:<folder>/"` loads `~/.gitconfig-<slug>` with name, email and signing key.
- **SSH** — each client has its own key behind a `Host github-<slug>` alias; `insteadOf` rewrites URLs of the client's orgs to it.

## AI agents

`sync` writes a "GitHub Accounts" section (table + rules: never switch accounts, verify before pushing) between markers in:

- `~/.claude/CLAUDE.md` (Claude Code)
- `~/.codex/AGENTS.md` (Codex)

Cursor keeps global User Rules in its settings, not on disk, so `sync` copies the block to your clipboard to paste in **Cursor Settings → Rules → User Rules**.

## Uninstall

```bash
brew uninstall gh-accounts          # or: gh extension remove accounts
rm ~/.local/bin/gh                  # the wrapper
rm -r ~/.config/gh-accounts
```

Your `includeIf`, `insteadOf`, SSH and GPG setup keep working as plain git config.

## Requirements

macOS, zsh, [GitHub CLI](https://cli.github.com) 2.40+ (multi-account), git, python3 (Xcode Command Line Tools).

## License

MIT
