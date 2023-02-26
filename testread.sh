#!/bin/bash

# testread.sh - A disk read benchmarking script
#
# Runs `find -exec cat > /dev/null` in a loop and writes
# time and byterate information to a log file.
#
# Copyright Mike Mallett <mike@nerdcore.net> (c) 2023
#
# This software is PUBLIC DOMAIN. For jurisdictions which do not
# recognize dedication to the public domain, this software is
# provided under the terms of the Creative Commons Zero (CC0)
# licence: https://wiki.creativecommons.org/wiki/CC0

# Which directory to read files from
READDIR="./"

# How many times to read the directory
LOOP=4

TIME="$(date +%F-%H%M%S)"

LOGFILE="readlog-${TIME}.log"

out(){
    echo "$1" | tee -a "${LOGFILE}"
}
FIXES=(" " "k" "M" "G" "T" "P" "E" "Z" "Y")
THE_BSIZE=""
bsize(){
    SUB=$1
    FIX=0
    while [ ${SUB} -gt 1024 ]; do
	SUB=$((SUB/1024))
	((FIX++))
    done
    THE_BSIZE="${SUB} ${FIXES[${FIX}]}iB"
    return ${FIX}
}
ratify(){
    out "Time: $2 seconds"
    RATE=$(($1/$2))
    EXCITE=""
    bsize ${RATE}
    for E in $(seq 1 $?); do
	EXCITE="${EXCITE}!"
    done
    RATEH="${THE_BSIZE}"
    out "Rate: ${RATE} bytes (${RATEH}) / second ${EXCITE}"
}

if [ ! -d "${READDIR}" ]; then
    echo "Failed to read directory ${READDIR}"
    exit 0
fi

DSIZE="$(du -sb ${READDIR} | awk '{print $1}')"
bsize "${DSIZE}"
DSIZEH="${THE_BSIZE}"
TSIZE=$((${DSIZE}*${LOOP}))
bsize "${TSIZE}"
TSIZEH="${THE_BSIZE}"

DF="$(df -h . | tail -n1)"
DEVICE="$(echo ${DF} | awk '{print $1}')"
FSIZE="$(echo ${DF} | awk '{print $2}')"
NAME="$(lsblk -n -o NAME ${DEVICE})"
MOUNT="$(lsblk -n -o MOUNTPOINT ${DEVICE})"
TYPE="$(lsblk -n -o TYPE ${DEVICE})"
MLINE="$(mount | grep ^${DEVICE})"
FSTYPE="$(echo ${MLINE} | awk '{print $5}')"
MNTOPTS="$(echo ${MLINE} | awk '{print $6}')"
UUID="$(lsblk -n -o UUID ${DEVICE})"

START="$(date +%s)"

out "Starting read test at ${TIME}"
out ""
out "${DF}"
out ""
out "Device: ${DEVICE}"
out "Filesystem size: ${FSIZE}B"
out "Mountpoint: ${MOUNT}"
out "Mount options: ${MNTOPTS}"
out "UUID: ${UUID}"
out "Device type: ${TYPE}"

if [ "${TYPE}" = "part" ]; then
    BLKDEV="$(lsblk -n -o PKNAME ${DEVICE})"
    SCSI="$(lsblk -n -o HCTL /dev/${BLKDEV})"
    SCSIINFO=$(dmesg | grep "scsi ${SCSI}")
    out "SCSI: ${SCSIINFO}"
elif [ "${TYPE}" = "raid1" ]; then
    out "RAID: $(grep ^${NAME} /proc/mdstat)"
fi

out "File system: ${FSTYPE}"
if [ -f "/proc/fs/${FSTYPE}/${NAME}/options" ]; then
    FSOPTS=""
    for FSOPT in $(cat /proc/fs/${FSTYPE}/${NAME}/options); do
	FSOPTS="${FSOPTS} ${FSOPT}"
    done
    out "${FSTYPE} options:${FSOPTS}"
fi

out ""
out "Source: ${READDIR}"
out "Rounds: ${LOOP}"
out "Data size: ${DSIZE} bytes (${DSIZEH})"
out "Total size: ${TSIZE} bytes (${TSIZEH})"

for ROUND in $(seq 1 ${LOOP}); do
    RSTART="$(date +%s)"
    out ""
    out "$(date)"
    out "Reading ${READDIR} Round ${ROUND} ..."
    # TODO: This doesn't seem to work...
    # `RESULT=`time 2>&1` leaves $RESULT empty
    RESULT=$(time find "${READDIR}" -type f -exec cat {} > /dev/null \; 2>&1)
    out "${RESULT}"
    REND="$(date +%s)"
    RTIME=$((${REND}-${RSTART}))
    ratify ${DSIZE} ${RTIME}
done

END="$(date +%s)"
out "Done: $(date)"

TOTAL="$((${END}-${START}))"

out ""
out "Total time reading ${TSIZEH} on ${DEVICE} mounted at ${MOUNT}: ${TOTAL} seconds"

ratify ${TSIZE} ${TOTAL}
RATE="$((${TSIZE} / ${TOTAL}))"
