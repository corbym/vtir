# Contributing

## Branch and PR naming

Branch names should reference the story they relate to:
```
story-042-short-description
```

PR titles should follow the same pattern:
```
STORY-042: Short description of what the PR does
```

If a PR covers multiple stories, list them all:
```
STORY-042 STORY-043: Short description
```

If a PR is not related to any story (dependency bumps, tooling, CI changes) prefix it with `chore:`:
```
chore: bump goreleaser to v2
```

The backlog agent uses these conventions to find and update the right stories automatically. If your PR doesn't follow them, the agent will skip it rather than guess.
