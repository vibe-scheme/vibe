# Contributing to Vibe

## Development Philosophy

Vibe is developed by conversing with AI models. Code is not written directly — it emerges from structured conversations between humans and models. Every contribution must include a chat document that memorializes that conversation.

This isn't a stylistic preference; it's central to what Vibe is. The project's goal is to build a language where humans and AI reason together about programs. The development process should embody that goal.

## Pull Request Requirements

Every PR must include:

1. **Exactly one new chat document** in `doc/chats/` documenting the conversation that produced the changes.

2. **The chat file must use the placeholder prefix `0000-`**, e.g. `0000-my-feature.md`. A GitHub Action will automatically renumber it to the next sequential number when the PR is merged.

3. **The chat must follow the format** documented in `AGENTS.md`:
   - Date and AI model used
   - Complete overview of all work done
   - Key decisions made
   - Implementation details
   - Files modified

4. **One session, one chat, one PR.** Do not split a single conversation across multiple chat files or multiple PRs. Do not combine unrelated sessions into one chat.

## Getting Started

### Understand the project

- Read [`AGENTS.md`](AGENTS.md) for full development guidance and DSL conventions
- Read [`doc/design/vision.md`](doc/design/vision.md) for Vibe's goals and architecture
- Read [`doc/design/macro-system.md`](doc/design/macro-system.md) for the current implementation roadmap
- Browse [`doc/chats/`](doc/chats/) to see how previous sessions were conducted

### Build from source

```bash
./build.sh build
```

On a clean checkout, the build script downloads a seed compiler (see [`RELEASING.md`](RELEASING.md)). Set `VIBE_SEED_TAG` to select a different published seed. Subsequent builds use the just-built `vibe_kernel` to compile itself.

**Requirements**: LLVM 21+ (`llvm-as`, `llvm-link`, `llc` must be available)

### Run tests

```bash
./build.sh test
```

## How to Work

1. Start a conversation with an AI model about the change you want to make.
2. Work through the implementation together, building and testing as you go.
3. At the end of the session, have the model create the chat document.
4. Name it `0000-descriptive-name.md` and place it in `doc/chats/`.
5. Open a PR. The chat will be renumbered automatically on merge.

## Code Standards

- **Fix at the source.** Don't add workarounds; fix the root cause.
- **Document functions.** Every function should have a comment explaining its purpose.
- **Balance parentheses carefully.** Unclosed `)` causes infinite parse loops; extra `)` can trigger spurious main generation.
- **Use `snake_case`** for LLVM functions and variables.
- **Test thoroughly.** Test components individually, then integration, then edge cases.

## Updating Documentation

If your changes affect the architecture, design decisions, or implementation status:

- Update the relevant design documents in `doc/design/`
- Update `doc/pages/index.html` if the public site needs to reflect the changes
- Update `AGENTS.md` if new conventions or patterns were established
