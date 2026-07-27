# Fetch Comments — GraphQL Queries and Fallbacks

## Fetching Review Comments via GraphQL

### Query for Reviews + Inline Comments

```graphql
query GetPRReviews($owner: String!, $repo: String!, $number: Int!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $number) {
      reviews(first: 100, states: [COMMENTED, CHANGES_REQUESTED]) {
        nodes {
          id
          author {
            login
          }
          body
          state
          comments(first: 100) {
            nodes {
              id
              author {
                login
              }
              body
              path
              line
            }
          }
        }
      }
      reviewThreads(first: 100) {
        nodes {
          id
          isResolved
          comments(first: 100) {
            nodes {
              id
              author {
                login
              }
              body
              path
              startLine
              line
            }
          }
        }
      }
    }
  }
}
```

### Invocation (with `gh api`)

```bash
gh api graphql \
  -f owner='OWNER' \
  -f repo='REPO' \
  -f number='PR_NUMBER' \
  -f query='<QUERY_ABOVE>'
```

---

## Fallback: REST API (TLS Certificate Errors)

If GraphQL fails with a TLS error, use the REST API:

### Fetch Reviews

```bash
curl -sf -H "Authorization: Bearer $(gh auth token)" \
  "https://api.github.com/repos/OWNER/REPO/pulls/PR_NUMBER/reviews" \
  | jq '.[] | select(.state == "CHANGES_REQUESTED" or .state == "COMMENTED") | {id, author: .user.login, body, state}'
```

### Fetch Inline Comments

```bash
curl -sf -H "Authorization: Bearer $(gh auth token)" \
  "https://api.github.com/repos/OWNER/REPO/pulls/PR_NUMBER/comments" \
  | jq '.[] | {id, author: .user.login, body, path, line}'
```

### Fetch Review Threads

```bash
curl -sf -H "Authorization: Bearer $(gh auth token)" \
  "https://api.github.com/repos/OWNER/REPO/pulls/PR_NUMBER/reviews" \
  | jq '.[] | .comments | .[] | {id, path, line, isResolved: false}'
```

---

## Parsing Results

After fetching, build a list of comments with:

```json
[
  {
    "id": "review-comment-id",
    "author": "username",
    "body": "comment text",
    "path": "src/file.ts",
    "line": 42,
    "type": "inline",
    "resolved": false
  }
]
```

Then filter by `author == CURRENT_USER` and count `resolved: false` entries.
