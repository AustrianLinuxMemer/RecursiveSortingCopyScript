# RecursiveSortingCopyScript
A script that recursivley traverses and copies a directory, sorting the copy order of .m4a files after the track number tag

# Backstory
As i tried to copy my music collection onto my MP3 player, i stumbled across a bug that makes the MP3 player sort tracks in an album after the creation timestamp of the file instead of the more sesible approach of using the track number in the file tags or the filename itself. Due to the manufacturer not updating the firmware anymore, i decided to write this script as a workaround of my MP3 Player's buggy track sorting

# Dependencies

This script requires the `ffprobe` utility of the `ffmpeg` library

It also expects that POSIX-standard tools and the `bash` shell are present.

Should a dependency be missing, then the script will give you an error message along the lines of "\<command\> is not installed. Please install it to use this script.".
