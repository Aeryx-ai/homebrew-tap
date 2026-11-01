# Aeryx Homebrew tap

[Sock](https://joinsock.com) for Homebrew.

```sh
brew install aeryx-ai/tap/sock            # sock CLI
brew install aeryx-ai/tap/sock-mcp        # sock MCP server
brew install --cask aeryx-ai/tap/sock     # Sock for Mac (macOS 26+)
```

The formulas build from source at the signed release tags of
[sock-cli](https://github.com/Aeryx-ai/sock-cli) and [sock-mcp](https://github.com/Aeryx-ai/sock-mcp)
(`--HEAD` builds `main`). The cask installs the signed app from `https://downloads.joinsock.com`.

Release workflows regenerate these files with `scripts/update.sh`; don't edit them by hand.
`make check` runs the tests and lint.
