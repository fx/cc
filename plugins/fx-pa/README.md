# fx-pa

Personal assistant tools for task extraction, scheduling, and productivity management.

## Overview

The fx-pa (Personal Assistant) plugin provides intelligent agents for managing personal productivity. It focuses on extracting actionable items from unstructured text and converting them into structured, manageable data.

## Components

### Agents (1)

- **task-extractor** - Extracts actionable tasks from text and returns structured JSON

## Installation

```bash
/plugin install fx-pa
```

## Usage

### Task Extraction

The task-extractor agent operates with isolated context to focus solely on extraction without interference from the broader conversation. Use it to parse tasks from emails, notes, messages, or any text containing actionable items.

**Invocation pattern:**

```
Use the task-extractor agent to extract tasks from: [your text]
```

Or via the Task tool:
```javascript
Task({
  description: "Extract tasks from text",
  prompt: "Extract tasks from this email: [email content]",
  subagent_type: "task-extractor"
})
```

**Agent reference:** `@agent-fx-pa:task-extractor`

### What Gets Extracted

The agent identifies actionable items including:
- Explicit intentions ("I need to...", "I should...")
- Commitments ("I'll...", "I will...")
- Assigned tasks
- Appointments and meetings
- Deadlines

### Output Format

Returns structured JSON with this schema:

```json
{
  "tasks": [
    {
      "description": "Task description",
      "capturedAt": "2025-11-08",
      "dueDate": "2025-11-15",
      "scheduledDate": "",
      "priority": "medium",
      "completed": false,
      "completedAt": ""
    }
  ]
}
```

**Fields:**
- **description**: Clear, actionable task description
- **capturedAt**: Date when task was captured (ISO 8601: YYYY-MM-DD)
- **dueDate**: Deadline date or empty string
- **scheduledDate**: Planned work date or empty string
- **priority**: `"high"`, `"medium"`, or `"low"`
- **completed**: `true` or `false`
- **completedAt**: Completion date or empty string

### Priority Levels

- **high**: Urgent language (ASAP, critical, immediately), extreme time pressure
- **medium**: Time-sensitive (soon, this week), near-term due dates (< 7 days)
- **low**: No urgency, far-off due dates (> 7 days), optional items

### Date Extraction

**dueDate** - Extracted from:
- Deadlines: "due Friday", "by March 1st"
- Appointments: "appointment on...", "scheduled for..."
- Meetings: "meeting Thursday"

**scheduledDate** - Extracted from:
- Planned work time: "I'll do this Monday"
- Scheduled actions: "Planning to tackle this Tuesday"

**Relative dates** are automatically converted:
- "tomorrow" → calculated date
- "next Monday" → calculated date
- "in 3 days" → calculated date

All dates use **ISO 8601 format** (YYYY-MM-DD).

## Examples

### Example 1: Email Processing

**Input:**
```
Extract tasks from this email:

Hi team,

Can you please review the Q4 budget by Friday? Also, I'll be
working on the presentation Monday, and we have our planning
meeting scheduled for next Wednesday at 10am.

Thanks!
```

**Output:**
```json
{
  "tasks": [
    {
      "description": "Review the Q4 budget",
      "capturedAt": "2025-11-08",
      "dueDate": "2025-11-15",
      "scheduledDate": "",
      "priority": "medium",
      "completed": false,
      "completedAt": ""
    },
    {
      "description": "Work on the presentation",
      "capturedAt": "2025-11-08",
      "dueDate": "",
      "scheduledDate": "2025-11-11",
      "priority": "low",
      "completed": false,
      "completedAt": ""
    },
    {
      "description": "Planning meeting",
      "capturedAt": "2025-11-08",
      "dueDate": "2025-11-13",
      "scheduledDate": "2025-11-13",
      "priority": "medium",
      "completed": false,
      "completedAt": ""
    }
  ]
}
```

### Example 2: Urgent Tasks

**Input:**
```
Extract tasks from: URGENT - production is down! Need to fix ASAP.
Also, when you get a chance, update the documentation.
```

**Output:**
```json
{
  "tasks": [
    {
      "description": "Fix production outage",
      "capturedAt": "2025-11-08",
      "dueDate": "",
      "scheduledDate": "",
      "priority": "high",
      "completed": false,
      "completedAt": ""
    },
    {
      "description": "Update the documentation",
      "capturedAt": "2025-11-08",
      "dueDate": "",
      "scheduledDate": "",
      "priority": "low",
      "completed": false,
      "completedAt": ""
    }
  ]
}
```

### Example 3: Meeting Notes

**Input:**
```
Extract tasks from these meeting notes:

- Sarah will send the contracts by end of week
- John completed the API integration yesterday
- We need to schedule a follow-up for next Tuesday
```

**Output:**
```json
{
  "tasks": [
    {
      "description": "Sarah will send the contracts",
      "capturedAt": "2025-11-08",
      "dueDate": "2025-11-15",
      "scheduledDate": "",
      "priority": "medium",
      "completed": false,
      "completedAt": ""
    },
    {
      "description": "API integration",
      "capturedAt": "2025-11-08",
      "dueDate": "",
      "scheduledDate": "",
      "priority": "low",
      "completed": true,
      "completedAt": "2025-11-07"
    },
    {
      "description": "Schedule follow-up meeting",
      "capturedAt": "2025-11-08",
      "dueDate": "2025-11-12",
      "scheduledDate": "",
      "priority": "low",
      "completed": false,
      "completedAt": ""
    }
  ]
}
```

## Use Cases

- **Email triaging**: Extract action items from incoming emails
- **Meeting notes**: Convert meeting discussions into actionable tasks
- **Project planning**: Parse project requirements into structured tasks
- **Note processing**: Extract TODOs from unstructured notes
- **Message parsing**: Identify commitments from chat conversations

## Model

The task-extractor agent uses **Haiku** for fast, efficient extraction with isolated context.

## Future Components

Planned additions to fx-pa:
- **scheduler** agent - Intelligent task scheduling based on priorities and deadlines
- **reminder** skill - Automated reminders for upcoming tasks
- **productivity-insights** agent - Analytics on task completion patterns
- **calendar-sync** command - Integration with calendar systems

## Contributing

To improve fx-pa:

1. Navigate to the plugin directory
2. Add new agents, skills, or commands
3. Test with real personal assistant workflows
4. Commit changes to fx/cc repository

## License

Part of the fx/cc Claude Code marketplace.
