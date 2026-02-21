#!/usr/bin/env fish

# Script to process the previous month's markdown file
# This script should be run on the 1st of each month

# Get the previous month in lowercase 3-letter format (jan, feb, mar, etc.)
set prev_month (date -d "last month" +%b | string lower)
set current_year (date +%Y)

# Set the directory where your markdown files are stored
set md_dir "$HOME/Documents/obsidian/03_quick_notes/programming_diary/"$current_year

# Change to the markdown directory
cd $md_dir
or begin
    echo "Error: Could not change to directory $md_dir"
    exit 1
end

# Check if the previous month's file exists
set input_file "$prev_month.md"
if not test -f $input_file
    echo "Error: File $input_file not found in $md_dir"
    exit 1
end

# Source the function (adjust path if needed)
source ~/.config/fish/functions/squash_headers.fish
or begin
    echo "Error: Could not source sh"
    exit 1
end

# Run the function
squash_headers $input_file

echo "Processed $input_file on "(date)
