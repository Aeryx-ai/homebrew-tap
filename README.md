# Aeryx Homebrew tap

[Sock](https://joinsock.com) for Homebrew.

```sh
brew install aeryx-ai/tap/sock            # sock CLI
brew install aeryx-ai/tap/sock-mcp        # sock MCP server
brew install --cask aeryx-ai/tap/sock     # Sock for Mac (macOS 26+)
```

Release workflows regenerate these files with `scripts/update.sh` from the manifests at
`https://downloads.joinsock.com/latest/`; don't edit them by hand. `make check` runs the tests and lint.
