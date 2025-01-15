#!/bin/bash

# Novel Events Extractor Notification Script
# This script runs the Novel Events Extractor and emails the results using Gmail SMTP.
#
# Prerequisites:
#   1. Gmail account with 2FA enabled
#   2. App Password generated for Gmail (https://myaccount.google.com/apppasswords)
#   3. GMAIL_APP_PASSWORD environment variable set with the app password
#
# Usage:
#   ./notify_novel_events.sh <email_address> [options]
#
# Options:
#   --whitelist "Calendar1,Calendar2"     Only include these calendars
#   --blacklist "Calendar1,Calendar2"     Exclude these calendars
#   --whitelist-file path/to/file.txt    Read whitelist from file
#   --blacklist-file path/to/file.txt    Read blacklist from file
#
# Example:
#   export GMAIL_APP_PASSWORD='your_16_char_app_password'
#   ./notify_novel_events.sh user@gmail.com --blacklist "Birthdays,Holidays"
#
# Note: The email address must be the same Gmail account used to generate the app password

# Check for required email argument
if [ $# -lt 1 ]; then
    echo "Usage: $0 <email_address> [options]"
    echo "Example: $0 user@example.com --blacklist \"Birthdays,Holidays\""
    echo "Note: GMAIL_APP_PASSWORD environment variable must be set"
    exit 1
fi

# Configuration
EMAIL="$1"
shift  # Remove email from arguments, leaving only options

if [ -z "$GMAIL_APP_PASSWORD" ]; then
    echo "Error: GMAIL_APP_PASSWORD environment variable is not set"
    echo "Set it with: export GMAIL_APP_PASSWORD='your_app_password'"
    exit 1
fi

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Run the Novel Events Extractor with any remaining arguments
cd "$SCRIPT_DIR"
swift run NovelEventsExtractor "$@"

# Check if novel_events.txt exists and has content
if [ -s "novel_events.txt" ]; then
    # Format and send email with proper headers
    (echo "Subject: Novel Events Update for $(date '+%Y-%m-%d')";
     echo "From: Novel Events Extractor <$EMAIL>";
     echo "Content-Type: text/plain";
     echo "";
     cat "novel_events.txt") | \
    curl --url "smtps://smtp.gmail.com:465" \
         --ssl-reqd \
         --mail-from "$EMAIL" \
         --mail-rcpt "$EMAIL" \
         --user "$EMAIL:$GMAIL_APP_PASSWORD" \
         --upload-file - \
         --silent
fi 