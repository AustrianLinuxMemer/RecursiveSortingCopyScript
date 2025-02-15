# RecursiveSortingCopyScript
A script that recursivley traverses and copies a directory, sorting the tracks in order of their track number

# Backstory
As i tried to copy my music collection onto my MP3 player, i stumbled across a bug that makes the MP3 player sort tracks in an album after the creation timestamp of the file instead of the more sesible approach of using the track number in the file tags or the filename itself. Due to the manufacturer not updating the firmware anymore, i decided to write this script as a workaround of my MP3 Player's buggy track sorting

# Dependencies

This script requires the `mediainfo` command

It also expects that POSIX-standard tools and the `bash` shell are present.

Should a dependency be missing, then the script will give you an error message along the lines of "\<command\> is not installed. Please install it to use this script.".

# Usage

`usage: nw-E39x.sh <source> <target> [-a|-r|-w] [-i] [-v SILENT | ERROR | WARNING | VERBOSE]`

- `-a`: **A**ppend the files in the destination (default)
- `-r`: **R**eplace the files in the destination
- `-w`: **W**ipe the destination

- `-i`: **I**nclude non-music files (Optional)

- `-v SILENT | ERROR | WARNING | VERBOSE`: Sets the **V**erbosity of the script (default: ERROR)

Beware that the ommission of `-i` can take up an significant time to sum up all files that will be copied
