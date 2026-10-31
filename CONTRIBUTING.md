# Contributing to Beakarr

This project is under active development, so small focused contributions are preferred over large unsolicited refactors.

## Before You Start

If you want to work on a bug fix, a small improvement, or a documentation update, feel free to open a pull request.

If you want to introduce a larger feature, change architecture, or do a broad refactor, please open an issue first so the change can be discussed before you spend time implementing it.

## Reporting Issues

Before opening a new issue:

- Search existing issues first to avoid duplicates
- Use a clear and descriptive title
- Include reproduction steps for bugs
- Include screenshots or logs when useful
- Mention the platform involved (Android, iOS, macOS, etc.)

## Pull Request Guidelines

Please keep pull requests focused and easy to review.

### Good pull requests

- Solve one problem at a time
- Include a clear description of the change
- Explain why the change is needed
- Mention how the change was tested
- Update documentation when behavior or setup changes

### Avoid

- Unrelated refactors mixed into feature work
- Large drive-by formatting changes
- API keys, credentials, private URLs, signing files, or other secrets in commits

### Development Setup

Install dependencies:

```bash
flutter pub get
```

Run the app locally:

```bash
flutter run -d macos
```

### Required Checks
Before opening a pull request, run:

```bash
flutter analyze
dart format --output=none --set-exit-if-changed .
flutter test
```
Pull requests should **not** introduce analyzer issues, formatting drift, or failing tests.

### Project Structure

The project follows a feature-first layout:

- `lib/core/` for shared infrastructure and reusable widgets
- `lib/features/<feature>/data`
- `lib/features/<feature>/domain`
- `lib/features/<feature>/presentation`
Please keep new code aligned with the existing structure.

### Code Style

A few project conventions matter:

- Prefer small widgets and focused helpers
- Prefer readable, modular code over large build methods
- Keep stateful logic in Riverpod providers/notifiers where possible
- Use shared design tokens and reusable widgets instead of hardcoded UI values

### Tests

Tests should be deterministic and should not rely on real network calls.

When adding or changing logic, add or update tests where it makes sense.

### Documentation

If your change affects setup, configuration, behavior, or developer workflow, update the relevant documentation in the same pull request.

That includes **README.md** and any related docs.

### Security

Do not commit:

- API keys
- signing files
- local credentials
- private server URLs if they are sensitive
- `android/key.properties`
- `.env` files or similar local secrets
Use example files or placeholder values when documentation needs configuration examples.

### Questions

If something is unclear, open an issue and ask before implementing a large change.
 