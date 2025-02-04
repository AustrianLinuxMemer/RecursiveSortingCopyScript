#!/bin/bash
filecount=0
completed=0
# 0 -> SILENT, 1 -> ERROR, 2 -> WARNING, 3 -> INFO, 4 -> VERBOSE
set_log_level=""
mode=""
exclude_non_music=""
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
    if [[ "$mode" == "w" ]]; then   
        rm -rf "$dest"
    fi
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
            log "Copying $(basename "$item") ($completed/$filecount)" 1 
            if [[ "$mode" == "r" ]]; then
                cp "$item" "$dest/"
            else            
                cp --update=none "$item" "$dest/"
            fi
        elif [ -d "$item" ]; then
            subdirectory_name=$(basename "$item")
            copy_directory "$item" "$dest/$subdirectory_name" "$include_non_music"
        fi
    done
}
usage() {
    log "usage: $0 <source> <target> [-a|-r|-w] [-i] [-v SILENT | ERROR | WARNING | VERBOSE]"
}
missing_origin() {
    log "missing origin" 1
}
missing_destination() {
    log "missing destination" 1
}
wrong_log_level() {
    log "log level must be SILENT, ERROR, WARNING, INFO or VERBOSE" 1
}
set_the_log_level() {
    log_string="$1"
    case $log_string in
        "SILENT")
            set_log_level="0"
            ;;
        "ERROR")
            set_log_level="1"
            ;;
        "WARNING")
            set_log_level="2"
            ;;
        "INFO")
            set_log_level="3"
            ;;
        "VERBOSE")
            set_log_level="4"
            ;;
        "")
            set_log_level="1"
            ;;
        *)
            wrong_log_level
            exit 1
            ;;
    esac
}
if [[ "$1" == "-h" || "$1" == "--help" || "$1" == "-?" ]]; then
    usage
    exit 0
fi
script_name="$0"
origin="$1"
destination="$2"

if [[ -z $origin ]]; then
    missing_origin
    exit 1
fi
if [[ -z $destination ]]; then
    missing_destination
    exit 1
fi

parse_dynamic_args() {
    mode=""
    exclude_non_music=""
    set_log_level=""
    script_name="$0"
    origin="$1"
    destination="$2"
    shift 2
    if [[ -z "$origin" ]]; then
        echo "origin must be present"
        exit 1
    fi
    if [[ -z "$destination" ]]; then
        echo "Destination must be present"
        exit 1
    fi
    while [[ $# -gt 0 ]]; do
        arg="$1"
        if [[ -z "$mode" ]]; then
            case "$arg" in
                "-a")
                    mode="a"
                    ;;
                "-r")
                    mode="r"
                    ;;
                "-w")
                    mode="w"
                    ;;
                *)
                    echo "usage"
                    exit 2
                    ;;
            esac    
        fi
        if [[ -z "$exclude_non_music" ]]; then
            if [[ "$arg" == "-i" ]]; then
                exclude_non_music="true"        
            fi    
        fi
        if [[ -z "$set_log_level" ]]; then
            if [[ "$arg" == "-v" ]]; then
                set_the_log_level "$2"        
            fi    
        fi
        shift 1
    done
    if [[ -z "$mode" ]]; then
        mode="a"
    fi
    if [[ -z "$exclude_non_music" ]]; then
        exclude_non_music="false"
    fi
    if [[ -z "$log_level" ]]; then
        set_the_log_level "1"
    fi
}

count_files "$origin" "$exclude_non_music"
read -p "Do you want to copy $filecount files? (y/n): " answer
if [[ "$answer" != "y" ]]; then
    log "Operation canceled."
    exit 0
fi
if [[ "$mode" == "w" ]]; then
    read -p "Are you sure you want to wipe $destination?
This action will delete everything in that directory and cannot be reversed. (y/n): " answer
    if [[ "$answer" != "y" ]]; then
        log "Operation canceled."
        exit 0
    fi
fi
if [[ "$mode" == "r" ]]; then
    read -p "Are you sure you want to replace files in $destination?
This action cannot be reversed. (y/n): " answer
    if [[ "$answer" != "y" ]]; then
        log "Operation canceled."
        exit 0
    fi
fi
copy_directory "$origin" "$destination" "$exclude_non_music"
