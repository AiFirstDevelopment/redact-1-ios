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
- **Every change must have 100% test coverage for the code being committed**:
  - For UI/frontend changes: Use DOM-query integration tests (Vitest + happy-dom)
  - For backend/worker changes: Use behavior tests
- **Every frontend change must have 85% DOM query test coverage**:
  - Add tests that query DOM elements (IDs, classes, attributes, text content)
  - Cover HTML structure, CSS classes, template rendering, and JavaScript behavior
  - Place tests in `frontend/src/*.test.ts` files following existing patterns
- **ALWAYS assume that failing tests are identifying a regression**
- **NEVER modify existing tests without asking permission first**
- **NEVER change tests to make broken code pass** - if tests fail, fix the code, not the tests

### Run Tests
```bash
# Worker tests
cd worker && npm test

# Frontend tests
cd frontend && npm test
```

## Deployment

**NEVER deploy without explicit permission.**

Deploy commands (only when explicitly asked):
```bash
# Worker deploy
cd worker && npx wrangler deploy

# Frontend deploy
cd frontend && npx wrangler pages deploy dist --project-name=redact-1
```
