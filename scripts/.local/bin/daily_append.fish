#!/usr/bin/env fish

# Script to append to diary
# This script should be run every day

# Get the previous month in lowercase 3-letter format (jan, feb, mar, etc.)
set this_month (date +%b | string lower)
set current_year (date +%Y)

# Set the directory where your markdown files are stored
set md_dir "$HOME/Documents/obsidian/07_quick_notes/programming_diary/"$current_year

# Change to the markdown directory
cd $md_dir
or begin
    echo "Error: Could not change to directory $md_dir"
    exit 1
end

# Check if the month's file exists
set input_file "$this_month.md"
if not test -f $input_file
    echo "File $input_file not found in $md_dir"
    echo "Creating $md_dir/$input_file"
    touch $input_file
end

# Source the function (adjust path if needed)
source ~/.config/fish/functions/append_diary.fish
or begin
    echo "Error: Could not source sh"
    exit 1
end

# Run the function
append_diary $input_file

echo "Appended to $input_file on "(date)
