---
name: agent-creator
description: MUST BE USED when user says 'create an agent', 'make an agent', 'new agent', 'build an agent', 'write an agent', 'add an agent', or describes agent functionality they need. Also use when editing existing agent markdown files or iterating on agent definitions. Load this skill BEFORE any agent-related work.
---

# Agent Creator

This skill provides guidance for creating effective agents for Claude Code plugins.

## About Agents

Agents are autonomous task handlers that extend Claude Code's capabilities for complex, multi-step operations. They are invoked via the Task tool with a `subagent_type` parameter and run as independent subprocesses with their own context.

### What Agents Provide

1. **Specialized Expertise** - Domain-specific knowledge and decision-making
2. **Autonomous Execution** - Multi-step workflows without user intervention
3. **Tool Coordination** - Orchestration of multiple tools to achieve goals
4. **Focused Context** - Isolated context window for complex tasks

### When to Create an Agent vs. Skill

| Create an Agent when... | Create a Skill when... |
|-------------------------|------------------------|
| Task requires autonomous multi-step execution | Knowledge/workflow should auto-trigger |
| User explicitly invokes via Task tool | Context should load on keyword detection |
| Subprocess isolation is beneficial | Information augments current conversation |
| Complex tool coordination needed | Procedural guidance for the main agent |

### Agent Anatomy

Every agent consists of a single markdown file:

```
agent-name.md
├── YAML frontmatter (required)
│   ├── name: (required) - unique identifier
│   ├── description: (required) - trigger conditions
│   ├── model: (optional) - sonnet/opus/haiku/inherit
│   ├── color: (optional) - terminal output color
│   └── tools: (optional) - restrict available tools
└── Markdown body (required)
    └── System prompt / instructions
```

## Agent Creation Process

Follow these steps in order when creating an agent.

### Step 1: Understanding the Agent's Purpose

Gather concrete examples of how the agent will be used:

**Key questions to ask:**
- "What specific task should this agent handle autonomously?"
- "What would a user say that should trigger this agent?"
- "What tools does this agent need access to?"
- "What decisions should this agent make independently?"
- "What should the agent output when finished?"

**Example for a `code-formatter` agent:**
- User: "Format all the JavaScript files in src/"
- User: "Clean up the code style in this file"
- User: "Apply prettier to my project"

Conclude when there's clarity on:
1. Agent's specific purpose and scope
2. Trigger phrases and invocation patterns
3. Required tools and capabilities
4. Expected outputs and success criteria

### Step 2: Designing the Agent Configuration

Analyze the use cases to determine:

#### 1. Agent Identifier (name)

Follow naming conventions:
- Lowercase letters, numbers, and hyphens only
- 3-50 characters, typically 2-4 words
- Clearly indicates primary function
- Avoids generic terms ("helper", "assistant", "manager")

**Good:** `code-formatter`, `pr-reviewer`, `test-generator`
**Bad:** `helper`, `code-assistant`, `thing-manager`

#### 2. Description (trigger conditions)

Write descriptions that ensure proper invocation:
- Start with "MUST BE USED when..." for mandatory triggers
- Or "Use this agent when..." for optional triggers
- Include specific trigger phrases users might say
- List 2-4 example scenarios

**Pattern:**
```
MUST BE USED when user asks to: [action 1], [action 2], [action 3].
[Brief capability description].
```

#### 3. Model Selection

| Model | When to Use |
|-------|-------------|
| `inherit` | Default - uses parent model (recommended) |
| `sonnet` | Complex reasoning, multi-step tasks |
| `haiku` | Fast, simple tasks, data extraction |
| `opus` | Most complex tasks requiring deep analysis |

#### 4. Color Selection

Choose colors based on agent purpose:
- **blue/cyan** - Analysis, review, inspection
- **green** - Generation, creation, building
- **yellow** - Validation, warnings, caution
- **red** - Security, critical operations
- **magenta** - Transformation, creative tasks
- **purple** - Implementation, coding

#### 5. Tool Restrictions (optional)

Omit the `tools` field for full access, or restrict to specific tools:
```yaml
tools: ["Read", "Glob", "Grep"]  # Read-only agent
tools: ["Read", "Write", "Edit", "Bash"]  # Full file access
```

Apply least-privilege principle: only include tools the agent needs.

### Step 3: Select Target Plugin

Determine which plugin should contain the agent:

**fx-cc Plugin Mapping:**
- **fx-dev** - Development workflows (PR, code review, CI/CD)
- **fx-meta** - Meta tools (skill/plugin/agent creation)
- **fx-mcp** - MCP server development
- **fx-research** - Research and technology scouting

If uncertain, use AskUserQuestion to confirm plugin selection.

### Step 4: Write the Agent File

Create the agent markdown file in the target plugin:

```bash
PLUGIN_PATH=~/.claude/plugins/marketplaces/fx-cc/plugins/<plugin-name>
cat > $PLUGIN_PATH/agents/<agent-name>.md
```

#### Frontmatter Template

```yaml
---
name: agent-name
description: "MUST BE USED when user asks to: [action 1], [action 2]. [Brief description of what the agent does]."
model: inherit
color: blue
tools: ["Tool1", "Tool2"]  # Optional - omit for full access
---
```

#### Body Structure Options

**Option A: Minimal Agent** (~50-100 words)
For simple, focused agents:

```markdown
# Agent Name

## Purpose
[One-liner purpose statement]

## Workflow
1. [Step 1]
2. [Step 2]
3. [Step 3]

## Key Behaviors
- [Behavior 1]
- [Behavior 2]
```

**Option B: Standard Agent** (~200-500 words)
For most agents:

```markdown
# Agent Name

## Purpose
[2-3 sentence description]

## Usage Examples

<example>
Context: [Situation that triggers agent]
user: "[User message]"
assistant: "I'll use the [agent-name] agent to [action]."
<commentary>
[Why agent should trigger]
</commentary>
</example>

## Core Responsibilities
1. [Responsibility 1]
2. [Responsibility 2]
3. [Responsibility 3]

## Workflow
1. **Step 1**: [Description]
2. **Step 2**: [Description]
3. **Step 3**: [Description]

## Quality Standards
- [Standard 1]
- [Standard 2]

## Output Format
[Expected output structure]
```

**Option C: Complex Orchestrator** (~500-1000+ words)
For agents that coordinate other agents or execute complex workflows:

```markdown
# Agent Name

## Purpose
[Comprehensive description]

## CRITICAL: MANDATORY STEPS
[Emphasize required workflow]

## Agent/Tool Reference
| Agent | subagent_type | Purpose |
|-------|---------------|---------|
| [Agent 1] | `plugin:agent-1` | [Purpose] |

## MANDATORY WORKFLOW STEPS

### STEP 1: [Phase Name]
[Detailed instructions with code blocks]

### STEP 2: [Phase Name]
[Detailed instructions]

## Error Handling
[How to handle failures]

## Success Criteria
[Checklist of completion criteria]
```

### Step 5: Add Usage Examples

Include `<example>` blocks in the description or body:

```markdown
<example>
Context: User wants to [action] after [situation]
user: "[User message - exact trigger phrase]"
assistant: "I'll use the [agent-name] agent to [what it does]."
<commentary>
[Explain why this triggers the agent and what happens]
</commentary>
</example>
```

Include 2-4 examples showing:
- Different phrasings for the same intent
- Both explicit and proactive triggering
- Context that makes triggering appropriate

### Step 6: Validate and Test

**Validation checklist:**
- [ ] Frontmatter has required `name` and `description` fields
- [ ] Name follows conventions (lowercase, hyphens, 3-50 chars)
- [ ] Description clearly states trigger conditions
- [ ] Model choice is appropriate for task complexity
- [ ] Tool restrictions follow least-privilege (if specified)
- [ ] Body provides clear instructions using imperative language
- [ ] Examples demonstrate typical usage patterns

**Testing:**
1. Reload Claude Code to pick up changes
2. Check agent appears in `/agents` list
3. Test trigger phrases in conversation
4. Verify Task tool invocation works correctly
5. Confirm agent produces expected outputs

### Step 7: Iterate

After testing:
1. Gather feedback on agent effectiveness
2. Refine trigger conditions if misfiring
3. Adjust instructions based on actual usage
4. Add examples from real invocations
5. Tune tool restrictions if needed

## Quality Standards

### Frontmatter Quality
- Name is unique within the plugin
- Description is specific enough to trigger correctly
- Description doesn't overlap with other agents
- Model and color choices are intentional

### Instruction Quality
- Clear, actionable instructions in imperative form
- Logical workflow sequence
- Explicit success/completion criteria
- Error handling guidance
- No ambiguous or contradictory instructions

### Integration Quality
- Doesn't conflict with existing agents
- Complements related skills and commands
- Follows plugin conventions
- Works correctly with specified tools

## Common Agent Patterns

See `references/agent-patterns.md` for detailed examples of:
- Review agents (code, PR, security)
- Generator agents (tests, docs, boilerplate)
- Orchestrator agents (SDLC, workflows)
- Monitor agents (CI/CD, health checks)
- Transformer agents (refactor, format, migrate)
