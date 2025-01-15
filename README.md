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
- Email notification support via Gmail SMTP

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

### Email Notifications

The project includes a notification script that can email the results using Gmail SMTP:

1. Prerequisites:
   - Gmail account with 2-Step Verification enabled
   - App Password generated for Gmail (https://myaccount.google.com/apppasswords)
   - GMAIL_APP_PASSWORD environment variable set with the app password

2. Usage:
```bash
# Set up Gmail App Password (one-time setup)
export GMAIL_APP_PASSWORD='your_16_char_app_password'

# Basic usage
./notify_novel_events.sh your.email@gmail.com

# With calendar filtering
./notify_novel_events.sh your.email@gmail.com --blacklist "Birthdays,Holidays"
./notify_novel_events.sh your.email@gmail.com --whitelist "Work,Personal"

# Using filter files
./notify_novel_events.sh your.email@gmail.com --blacklist-file blacklist.txt
./notify_novel_events.sh your.email@gmail.com --whitelist-file whitelist.txt
```

3. For daily notifications, add to crontab:
```bash
# Add to crontab to run daily at 9 AM (with optional calendar filtering)
0 9 * * * export GMAIL_APP_PASSWORD='your_app_password'; cd /path/to/novel-events-extractor && ./notify_novel_events.sh your.email@gmail.com --blacklist "Birthdays,Holidays"
```

Note: The email address must be the same Gmail account used to generate the app password.

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
- For email notifications:
  - Gmail account with 2-Step Verification
  - Gmail App Password

## How It Works

The program uses several strategies to identify novel events:

1. **Pattern Detection**: Analyzes your historical events to identify regular patterns based on:
   - Event titles and their similarities
   - Time of day (within 1-hour windows)
   - Calendar context

2. **Novelty Analysis**: Events are scored based on how well they match existing patterns. Events with low pattern scores are considered novel.

3. **Calendar Filtering**: Supports both blacklisting and whitelisting calendars to customize which events are analyzed.

4. **Email Notifications**: Uses Gmail SMTP with app-specific passwords for secure delivery of results.

## To Do
- Make the "days to look ahead" a command line argument
- Why is "Jan 20 1400 Nicole teaching at MRU [Cam Marsollier]" showing up again? It's not novel at all.
- create scheduler to run this on a regular basis