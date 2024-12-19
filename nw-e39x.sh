#!/bin/bash
filecount=0
completed=0

# List of dependencies
dependencies=("ffprobe" "cp" "mkdir" "basename" "grep")

# Function to check if a command is available
check_dependency() {
    local command="$1"
    if ! command -v "$command" &> /dev/null; then
        echo "$command is not installed. Please install it to use this script."
        exit 1
    fi
}

# Check each dependency
for dependency in "${dependencies[@]}"; do
    check_dependency "$dependency"
done

count_files() {
    local src="$1"
    # Use a for loop to iterate over the items in the directory
    for item in "$src"/*
    do
        if [ -f "$item" ]; then
            filecount=$((filecount+1))
        elif [ -d "$item" ]; then
            count_files "$item"
        fi
    done
}
copy_directory() {
    # Setting up Variables
    local src="$1"
    local dest="$2"
    local sortedFiles=()
    local unsortedFiles=()
    local dirs=()
    # Populate the arrays "sortedFiles" "unsortedFiles" and "dirs"
    mkdir -p "$dest"
    for item in "$src"/*
    do
        if [ -f "$item" ]; then
            filename=$(basename "$item")
            if [[ "$filename" =~ \.m4a$ ]]; then
                trackNumber=$(ffprobe -v error -show_format -show_streams "$item" | grep -oP 'TAG:track=\K\d+')
                if [ -z "$trackNumber" ]; then 
                    unsortedFiles+=("$item")
                else                
                    sortedFiles["$trackNumber"]="$item"
                fi
            else
                unsortedFiles+=("$item")
            fi
        elif [ -d "$item" ]; then
            dirs+=("$item")
        fi
    done
    # Concantate the three arrays together
    local files=()
    local files+=("${sortedFiles[@]}" "${unsortedFiles[@]}" "${dirs[@]}" )
    for item in "${files[@]}"
    do
        if [ -f "$item" ]; then
            completed=$((completed+1))
            echo "Copying $(basename "$item") ($completed/$filecount)"            
            cp "$item" "$dest/"
        elif [ -d "$item" ]; then
            subdirectory_name=$(basename "$item")
            copy_directory "$item" "$dest/$subdirectory_name"
        fi
    done
}
origin=$1
destination=$2
count_files "$origin"
read -p "Do you want to copy $filecount files? (y/n): " answer
if [[ "$answer" != "y" ]]; then
    echo "Operation canceled."    
    exit 0
fi
copy_directory $origin $destination

