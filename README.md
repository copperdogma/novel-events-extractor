# Novel Events Extractor

A Swift command-line tool that analyzes your calendar events to identify novel or unusual events in the upcoming two weeks. It uses pattern recognition to learn your regular schedule and highlights events that deviate from your normal patterns.

## Features

- Analyzes historical calendar events to learn regular patterns
- Identifies novel events based on frequency and similarity
- Flexible pattern matching:
  - Recognizes similar event titles
  - Considers events within an hour of each other as potentially related
  - Maintains calendar context for better pattern recognition
- Calendar filtering with blacklist/whitelist support
- Outputs results to both console and file

## Usage

1. Build the project:
```bash
swift build
```

2. Run the program:
```bash
# Basic usage
swift run NovelEventsExtractor

# With calendar filtering
swift run NovelEventsExtractor --blacklist "Birthdays,Holidays"
swift run NovelEventsExtractor --whitelist "Work,Personal"

# Using filter files
swift run NovelEventsExtractor --blacklist-file blacklist.txt
swift run NovelEventsExtractor --whitelist-file whitelist.txt

# Enable debug output
swift run NovelEventsExtractor --debug
```

### Calendar Filtering

You can filter which calendars to analyze using either blacklists (exclude specific calendars) or whitelists (include only specific calendars):

- **Blacklist options**:
  - `--blacklist "Calendar1,Calendar2"` - Comma-separated list of calendars to exclude
  - `--blacklist-file path/to/file.txt` - File containing calendar names to exclude (one per line)

- **Whitelist options**:
  - `--whitelist "Calendar1,Calendar2"` - Comma-separated list of calendars to include
  - `--whitelist-file path/to/file.txt` - File containing calendar names to include (one per line)

- **Debug output**:
  - `--debug` - Enable detailed debug output, including calendar filtering information

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

3. **Calendar Filtering**: Supports both blacklisting and whitelisting calendars to customize which events are analyzed.

## To Do
- Finish emailer
    - ensure secrets are pulled from the environment if possible
- create scheduler to run this on a regular basis
- have output options after generating the file, like email or slack
- Convert calendar source to google calendar which will be more widely useful? or at least add support for it? It'll probabyl be super annoying for people to give gcal access to their command line app
- Make the "days to look ahead" a command line argument
- Why is "Jan 20 1400 Nicole teaching at MRU [Cam Marsollier]" showing up again? It's not novel at all.