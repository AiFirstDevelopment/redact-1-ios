# Claude Instructions for Redact-1

## Git Commit Policy

**NEVER commit changes unless explicitly asked by the user.**

Do not infer that a commit should be performed based on:
- Recent prompt history
- Completing a task
- Any implicit suggestion

Only commit when the user explicitly says something like "commit", "create a commit", "git commit", etc.

## Testing

**NEVER change tests unless explicitly asked by the user.**

### Testing Rules
- **Every SwiftUI view change must have ViewInspector test coverage**
- **Every worker change must have behavior test coverage**
- **ALWAYS assume that failing tests are identifying a regression**
- **NEVER modify existing tests without asking permission first**
- **NEVER change tests to make broken code pass** - if tests fail, fix the code, not the tests

### Run Tests
```bash
# iOS view tests
xcodebuild test -project Redact1.xcodeproj -scheme Redact1 -destination 'platform=iOS Simulator,OS=latest,name=iPhone 16' -only-testing:Redact1Tests

# Worker tests
cd worker && npm test
```

## Deployment

**NEVER deploy without explicit permission.**

Deploy commands (only when explicitly asked):
```bash
# Worker deploy
cd worker && npx wrangler deploy
```
