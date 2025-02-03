#!/bin/bash
filecount=0
completed=0
# 0 -> ALWAYS, 1 -> ERROR, 2 -> WARNING, 3 -> INFO, 4 -> VERBOSE
set_log_level="1"
mode="a"
allowed_mimes=("audio/mp3" "audio/x-mp3" "audio/aac" "audio/x-aac" "audio/m4a" "audio/x-m4a" "video/mp4" "video/x-mp4" "audio/x-ms-wma" "audio/x-wav" "audio/wav" "audio/mpeg")
# List of dependencies
dependencies=("mediainfo" "cp" "mkdir" "basename")

# Logging function
log() {
    local message="$1"
    local loglevel="$2"
    if [[ $loglevel == "" ]]; then
        echo "$message"
        return 0    
    fi
    if [[ $loglevel -le $set_log_level ]]; then
        echo "$message"
        return 0    
    fi
}

# Function to check if a command is available
check_dependency() {
    local command="$1"
    if ! command -v "$command" &> /dev/null; then
        log "$command is not installed. Please install it to use this script." 0
        exit 1
    fi
}

# Check each dependency
for dependency in "${dependencies[@]}"; do
    check_dependency "$dependency"
done

# extracting the track number
extract_track_number() {
    local file_name="$1"
    echo $(mediainfo --Inform="General;%Track/Position%" "$file_name")
}
# error codes
error_codes() {
    error_code="$1"
    log_level="$2"
    item="$3"
    if [[ $error_code -eq 1 ]]; then
        log "($item) No path" $log_level
    elif [[ $error_code -eq 2 ]]; then
        log "($item) unsupported file format" $log_level
    elif [[ $error_code -eq 3 ]]; then
        log "($item) Track number is not a number" $log_level
    elif [[ $error_code -eq 4 ]]; then
        log "($item) Mediainfo failed" $log_level
    else
        log "($item) unknown error" $log_level
    fi
}
is_supported_audio_file() {
    if [[ "${allowed_mimes[@]}" =~ "$1" ]]; then
        return 0
    else
        return 1
    fi
}
# getting the track number
get_track_number() {
    local item="$1"
    local no_numbers="$2"
    if [[ -z $item ]]; then       
        return 1    
    fi
    is_supported_audio_file $(file --mime-type -b "$item")
    is_a_supported_audio_file=$?
    if [[ ! $is_a_supported_audio_file -eq 0 ]]; then
        return 2    
    fi
    local trackNumber="$(mediainfo --Inform="General;%Track/Position%" "$item")"
    local status="$?"
       
    if [[ $status != "0" ]]; then
        return 4
    fi
    if [[ -z $no_numbers ]]; then
        if [[ -z $trackNumber ]]; then
            echo "0"
            return 0
        fi
        if [[ ! $trackNumber =~ ^[0-9]+$ ]]; then
            return 3
        fi
        local strippedNumber="${trackNumber##0}"
        if [[ $strippedNumber == "" ]]; then
            strippedNumber="0"                
        fi
        echo "$strippedNumber"
    fi
    return 0
}

# counting up the files
count_files() {
    local src="$1"
    local exclude_non_music="$2"
    # Use a for loop to iterate over the items in the directory
    for item in "$src"/*
    do
        if [ -f "$item" ]; then
            if [[ $exclude_non_music == "false" ]]; then
                filecount=$((filecount+1))
            else
                get_track_number "$item" "q"
                status=$?
                if [[ $status -eq 0 ]]; then
                    filecount=$((filecount+1))
                else
                    error_codes "$status" 2 "$item"
                fi
            fi
        elif [ -d "$item" ]; then
            count_files "$item" "$include_non_music"
        fi
    done
}

# copying
copy_directory() {
    # Setting up Variables
    local src="$1"
    local dest="$2"
    local exclude_non_music="$3"
    local sortedFiles=()
    local unsortedFiles=()
    local dirs=()
    # Populate the arrays "sortedFiles" "unsortedFiles" and "dirs"
    mkdir -p "$dest"
    for item in "$src"/*
    do
        if [ -f "$item" ]; then
            filename=$(basename "$item")
            trackNumber=$(get_track_number "$item")
            status=$?
            if [[ $status -eq 0 ]]; then
                sortedFiles["$trackNumber"]="$item"
            else
                error_codes "$status" 3 "$item"
            fi
        elif [ -d "$item" ]; then
            dirs+=("$item")
        fi
    done
    # Concantate the three arrays together
    local files=()
    if [ "$exclude_non_music" == "false" ]; then
        files+=( "${sortedFiles[@]}" "${dirs[@]}" )
    else
        files+=( "${sortedFiles[@]}" "${unsortedFiles[@]}" "${dirs[@]}" )
    fi
    for item in "${files[@]}"
    do
        if [ -f "$item" ]; then
            completed=$((completed+1))
            log "Copying $(basename "$item") ($completed/$filecount)" 3
            if [[ "$mode" == "r" ]]; then
                cp "$item" "$dest/"
            else            
                cp -n "$item" "$dest/"
            fi
        elif [ -d "$item" ]; then
            subdirectory_name=$(basename "$item")
            copy_directory "$item" "$dest/$subdirectory_name" "$include_non_music"
        fi
    done
}
usage() {
    log "usage: $0 <source> <target> [-a|-r|-w] [-i] [-v ALWAYS | ERROR | WARNING | VERBOSE]" 0
}
missing_origin() {
    log "missing origin" 1
}
missing_destination() {
    log "missing destination" 1
}
wrong_log_level() {
    log "log level must be 0, 1, 2 or 3" 1
}
if [[ "$1" == "-h" || "$1" == "--help" || "$1" == "-?" ]]; then
    usage
    exit 0
fi
origin="$1"
destination="$2"
exclude_non_music="true"
if [[ -z $origin ]]; then
    missing_origin
    exit 1
fi
if [[ -z $destination ]]; then
    missing_destination
    exit 1
fi
case $3 in
    "-a")
        mode="a"
        ;;
    "-r")
        mode="r"
        ;;
    "-w")
        mode="w"
        ;;
    "-i")
        exclude_non_music="false"
        ;;
    "-v")
        set_log_level="$4"
        ;;
    "")
        ;;
    *)
        usage
        exit 1
        ;;
esac
case $4 in
    "-i")
        exclude_non_music="false"
        ;;
    "-v")
        set_log_level="$5"
        ;;
    "")
        ;;
    *)
        usage
        exit 1
        ;;
esac
case $5 in
    "-v")
        set_log_level="$6"
        ;;
    "")
        ;;
    *)
        usage
        exit 1
        ;;
esac
log "Mode: $mode" 4
log "Exclude: $exclude_non_music" 4
log "Verbosity $set_log_level" 4
count_files "$origin" "$exclude_non_music"
read -p "Do you want to copy $filecount files? (y/n): " answer
if [[ "$answer" != "y" ]]; then
    log "Operation canceled." 1
    exit 0
fi
if [[ "$mode" == "w" ]]; then
    read -p "Are you sure you want to wipe $destination?\n
            This action will delete everything in that directory and cannot be reversed. (y/n): " answer
    if [[ "$answer" != "y" ]]; then
        log "Operation canceled." 1
        exit 0
    else
        rm -rf "$origin/*"
    fi
fi
if [[ "$mode" == "r" ]]; then
    read -p "Are you sure you want to replace files in $destination?\n
            This action cannot be reversed. (y/n): " answer
    if [[ "$answer" != "y" ]]; then
        log "Operation canceled." 1
        exit 0
    fi
fi
copy_directory "$origin" "$destination" "$exclude_non_music"
