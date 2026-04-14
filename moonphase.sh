#!/bin/sh
#
# Copyright (c) 2026 Mike Mallett <mike@nerdcore.net>
#
# All rights given. This work is in the public domain.
# After all, it's a moon phase calculator; How could anyone "own" this??
#
# Instructions:
#   https://calculatorian.com/en/articles/time-and-date/calculate-moon-phase-any-date
# Unicode chars:
#   https://unicodeplus.com/block/1F300
#
## +------------+-----------------+---------------------------------------+---------+
## |  Moon Age  |      Phase      |            What You See               | Unicode |
## |   (days)   |                 |                                       | U+..  C |
## +------------+-----------------+---------------------------------------+---------+
## |          0 |    New Moon     | Moon between Earth and Sun, invisible | 1F311 🌑|
## |    ~1 to 6 | Waxing Crescent | Thin sliver growing on the right side | 1F312 🌒|
## |       ~7.4 |  First Quarter  | Right half illuminated                | 1F313 🌓|
## |   ~8 to 13 |  Waxing Gibbous | More than half lit, still growing     | 1F314 🌔|
## |      ~14.8 |    Full Moon    | Fully illuminated                     | 1F315 🌕|
## |  ~15 to 21 |  Waning Gibbous | More than half lit, shrinking         | 1F316 🌖|
## |      ~22.1 |   Last Quarter  | Left half illuminated                 | 1F317 🌗|
## |  ~23 to 29 | Waning Crescent | Thin sliver on the left, shrinking    | 1F318 🌘|
## +------------+-----------------+---------------------------------------+---------+

# Simple method:
# Step 1: Pick a reference new moon, such as 1970-01-07
REFDATE="536400"
# Step 2: Count the number of days between your reference date and
#   your target date. If your target is in the past, count backward (the
#   math still works).
# Step 3: Divide by 29.53059 and take the remainder. That remainder is
#   the Moon's "age" in days since the last new moon.
SYNOD="29.53059"

# Advanced method:
# 29.5305888531 + 0.00000021621T - 3.64 x 10^-10 T^2 days
# where T is the number of Julian centuries since January 1, 2000.

if [ -x "$(which bc 2>/dev/null)" ]; then
    CALC="bc"
elif [ -x "$(which dc 2>/dev/null)" ]; then
    CALC="dc"
else
    echo "ERROR: Could not execute \`bc\` nor \`dc\`, needed for the maths."
    exit 1
fi

NOW=$(date +%s)
if [ -n "$1" ]; then
    TARGET="$(date +%s --date="$1")"
    if [ $? -ne 0 ]; then
	exit 2
    fi
else
    TARGET=${NOW}
fi
if [ ${TARGET} -lt ${NOW} ]; then
    WHEN="was"
elif [ ${TARGET} -gt ${NOW} ]; then
    WHEN="will be"
else
    WHEN="is"
fi

SECDIFF="$((${TARGET}-${REFDATE}))"

if [ "${CALC}" = "bc" ]; then
    REMAINDER="$(echo "(${SECDIFF} / 86400) / ${SYNOD}" | bc -l | awk -F. '{print $2}')"
    PHASE="$(echo "0.${REMAINDER} * ${SYNOD}" | bc -l | awk -F. '{print $1}')"
elif [ "${CALC}" = "dc" ]; then
    REMAINDER="$(echo "10k ${SECDIFF} 86400 / ${SYNOD} / p" | dc | awk -F. '{print $2}')"
    PHASE="$(echo "0.${REMAINDER} ${SYNOD} * p" | dc | awk -F. '{print $1}')"
fi
if [ -z "${PHASE}" ]; then
    PHASE=0
fi

FULLDATE="$(date --date="@${TARGET}" "+%A %B %e, %Y")"
if [ ${PHASE} -lt 2 ]; then
    PHASENAME="new"
    MOONCHAR="🌑"
elif [ ${PHASE} -ge 2 ] && [ ${PHASE} -lt 6 ]; then
    PHASENAME="waxing crescent"
    MOONCHAR="🌒"
elif [ ${PHASE} -ge 6 ] && [ ${PHASE} -le 8 ]; then
    PHASENAME="first quarter"
    MOONCHAR="🌓"
elif [ ${PHASE} -gt 8 ] && [ ${PHASE} -lt 13 ]; then
    PHASENAME="waxing gibbous"
    MOONCHAR="🌔"
elif [ ${PHASE} -ge 14 ] && [ ${PHASE} -le 15 ]; then
    PHASENAME="full"
    MOONCHAR="🌕"
elif [ ${PHASE} -gt 15 ] && [ ${PHASE} -lt 21 ]; then
    PHASENAME="waning gibbous"
    MOONCHAR="🌖"
elif [ ${PHASE} -ge 21 ] && [ ${PHASE} -le 23 ]; then
    PHASENAME="last quarter"
    MOONCHAR="🌗"
else
    PHASENAME="waning crescent"
    MOONCHAR="🌘"
fi
echo "On ${FULLDATE} the phase ${WHEN} a ${PHASENAME} moon: ${MOONCHAR}"
