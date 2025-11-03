# fx-tech

Technology research and recommendation agent for finding and evaluating libraries, frameworks, and software solutions.

## Overview

The fx-tech plugin provides specialized technology research capabilities through the tech-scout agent, which excels at finding the best tools for specific use cases with a strong preference for self-hosted solutions.

## Components

### Agents

- **tech-scout** - Researches and recommends libraries, technologies, or software solutions for specific use cases

## Usage

### Finding a Library or Technology

```python
# Research technology options
Task(
    description="Research collaboration tools",
    prompt="I need to add real-time collaborative editing to my web application",
    subagent_type="tech-scout"
)
```

### Finding Self-Hosted Alternatives

```python
# Find self-hosted solutions
Task(
    description="Find self-hosted alternative",
    prompt="What's a good self-hosted alternative to Slack for team communication?",
    subagent_type="tech-scout"
)
```

### Evaluating Technology Stacks

```python
# Evaluate options for a feature
Task(
    description="Evaluate auth libraries",
    prompt="What's the best authentication library for a Next.js application?",
    subagent_type="tech-scout"
)
```

## Agent Description

### tech-scout

A technology research specialist with deep expertise in evaluating open source software, libraries, and technical solutions. Uses a systematic research methodology to provide data-backed recommendations.

**Research Methodology:**

1. **GitHub Repository Search** - Uses GitHub API to find top repositories by stars, activity, and community engagement
2. **Awesome Lists Discovery** - Searches for curated "awesome-{topic}" repositories
3. **Web Intelligence Gathering** - Performs web searches to identify trends and community sentiment

**Evaluation Criteria:**

- Strong preference for self-hosted/on-premise solutions
- Active maintenance and responsive issue resolution
- Strong documentation and community support
- Ease of deployment and operational complexity
- Licensing implications for commercial use

**Output Format:**

- **Top Pick**: Single best solution with 2-3 key reasons
- **Alternatives**: 2-3 other strong options
- **Key Factors**: 3 most important decision criteria
- **Self-Hosted vs Cloud**: Explicit reasoning if recommending cloud services

## Examples

### Example 1: Real-Time Collaboration

```python
Task(
    description="Find collaboration library",
    prompt="I need to add real-time collaborative editing to my web application. What library should I use?",
    subagent_type="tech-scout"
)
```

Expected output style:
```
Top Pick: Yjs - CRDT-based, framework-agnostic, excellent offline support

Alternatives:
- ShareDB: Operational Transform, battle-tested, good for JSON documents
- Automerge: CRDT library, strong consistency, TypeScript support

Key Factors:
1. Conflict resolution approach (CRDT vs OT)
2. Framework compatibility
3. Offline capability requirements
```

### Example 2: Self-Hosted Solutions

```python
Task(
    description="Find self-hosted chat",
    prompt="What's a good self-hosted alternative to Slack?",
    subagent_type="tech-scout"
)
```

Expected output style:
```
Top Pick: Mattermost - Feature parity with Slack, active development, Docker deployment

Alternatives:
- Rocket.Chat: More customizable, broader integrations
- Zulip: Unique threading model, academia-focused

Key Factors:
1. Deployment complexity (Docker vs manual)
2. Integration ecosystem
3. Mobile app quality
```

### Example 3: Technology Stack Choice

```python
Task(
    description="Choose database",
    prompt="What database should I use for a high-write event logging system?",
    subagent_type="tech-scout"
)
```

## Integration with Other Plugins

Works well with:
- **fx-sdlc** - Research technologies during planning phase
- **fx-pr** - Document technology choices in PRs

## Best Practices

1. **Be specific** - The more context you provide, the better the recommendations
2. **Mention constraints** - Include requirements like "self-hosted", "TypeScript support", "low latency"
3. **State use case** - Explain what problem you're solving
4. **Consider trade-offs** - tech-scout will highlight key decision factors
5. **Verify recommendations** - Always review the suggested technologies against your specific needs

## Configuration

tech-scout uses:
- GitHub API via `gh` CLI for repository searches
- Web search for community sentiment
- Awesome lists for curated recommendations

## Troubleshooting

### No Results Found

If tech-scout doesn't find good options:
1. Broaden your search terms
2. Try alternative keywords
3. Consider if the use case is too specific
4. Check if you need a custom solution

### Recommendations Don't Fit

If recommendations don't match your needs:
1. Provide more context about your requirements
2. Specify must-have features explicitly
3. Mention technologies you've already tried
4. Clarify deployment constraints

## Contributing

To enhance the tech-scout agent:

1. Update `agents/tech-scout.md` with improved methodology
2. Add new evaluation criteria
3. Update README with new examples
4. Test with various use cases

## License

Part of the fx/cc Claude Code marketplace.
