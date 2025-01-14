# Novel Events Extractor

A Swift command-line tool that analyzes your calendar events to identify novel or unusual events in the upcoming two weeks. It uses pattern recognition to learn your regular schedule and highlights events that deviate from your normal patterns.

## Features

- Analyzes historical calendar events to learn regular patterns
- Identifies novel events based on frequency and similarity
- Flexible pattern matching:
  - Recognizes similar event titles
  - Considers events within an hour of each other as potentially related
  - Maintains calendar context for better pattern recognition
- Calendar filtering with blacklist support
- Outputs results to both console and file

## Usage

1. Build the project:
```bash
swift build
```

2. Run the program:
```bash
swift run
```

The program will:
- Request calendar access (required on first run)
- Analyze your calendar events from the past year
- Identify novel events in the next 14 days
- Output results to `novel_events.txt`

## Requirements

- macOS with Calendar access
- Swift 5.9 or later

## How It Works

The program uses several strategies to identify novel events:

1. **Pattern Detection**: Analyzes your historical events to identify regular patterns based on:
   - Event titles and their similarities
   - Time of day (within 1-hour windows)
   - Calendar context

2. **Novelty Analysis**: Events are scored based on how well they match existing patterns. Events with low pattern scores are considered novel.

3. **Calendar Filtering**: Supports blacklisting specific calendars (e.g., "Birthdays") to exclude them from analysis. 


## To Do
- add command line switch for blacklists and whitelists, accepting either a file or a comma separated list of calendar names
- create tests
- make some sort of scheduler to run this on a regular basis
- have output options after generating the file, like email or slack