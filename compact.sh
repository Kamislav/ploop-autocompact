#!/bin/bash
# compact.sh by Devon of ByteOnSite for OpenVZ
# Distribute freely with link to http://blog.byteonsite.com/?p=87

# SETTINGS

# Config Directory
CFG="/opt/vzcompact"

# VZ Partition
VZ=`cat $CFG/compact.vzdir 2>/dev/null`
# Run Compact Automatically Every X Runs. Default: 96 runs, if run every 15 minutes this is every 24 hours.
ONXRUNS=`cat $CFG/compact.onxruns 2>/dev/null`
# Minimum Free Space in MB.  Will attempt to compact if free space drops below this.  Default: automatically generated, 5% free space.
MINFREE=`cat $CFG/compact.minfree 2>/dev/null`
# Email Address
EMAIL=`cat $CFG/compact.email 2>/dev/null`
# Log enabled
LOG=`cat $CFG/compact.logging 2>/dev/null`
LOGDIR="/var/log/vzcompact"

# END SETTINGS

# DEFAULT SETTINGS

# Default VZ Partition
if [ ! $VZ ]; then
	VZ="/vz"
	echo $VZ > $CFG/compact.vzdir
fi
# Default ONXRUNS
if [ ! $ONXRUNS ]; then
	ONXRUNS=96
	echo $ONXRUNS > $CFG/compact.onxruns
fi
# Default MINFREE (5% of Total Partition)
if [ ! $MINFREE ]; then
	MINFREE=$[`df -PBM $VZ | awk 'NR==2 {print $2}' | cut -f1 -dM`/20]
	echo $MINFREE > $CFG/compact.minfree
fi
if [ ! $LOG ]; then
	LOG=1
	echo $LOG > $CFG/compact.logging
fi

# END DEFAULT SETTINGS

# LOGIC

FREESPACE=`df -PBM $VZ | awk 'NR==2 {print $4}' | cut -f1 -dM`

# DEBUG
if [ "$1" = "debug" ]; then
	echo "CFG: $CFG"
	echo "VZ: $VZ"
	echo "FREESPACE: ${FREESPACE}MB"
	echo "MINFREE: ${MINFREE}MB"
	echo "ONXRUNS: $ONXRUNS"
	echo "LOG: $LOG"
	echo "LOGDIR: $LOGDIR"
	echo "EMAIL: $EMAIL"
	if [ ! -f "/bin/mail" ]; then
		echo "MAILX: NOT FOUND. EMAILS WON'T BE SENT ON WARNING"
	fi
	exit 0
fi
# END DEBUG

i=`cat $CFG/compact.count`
if [ ! "$i" ] || [ "$i" -eq $ONXRUNS ]; then
	i=1
fi
if [ $i -eq 1 ] || [ $FREESPACE -lt $MINFREE ]; then
	# Run compact for every VPS
	stdout="/dev/null"
    if [ $LOG -eq 1 ]; then
    	stdout="$LOGDIR/compact.log"
    fi
	for veid in `vzlist -H -o veid`
	do
		date=`date`
		echo "Starting compact on VEID $veid at $date.." >$stdout 2>&1
		vzctl compact $veid >$stdout 2>&1
	done
	# Check disk space again
	FREESPACE=`df -PBM $VZ | awk 'NR==2 {print $4}' | cut -f1 -dM`
	if [ $FREESPACE -lt $MINFREE ]; then
		message="Unable to compact containers enough to reduce free space below MINFREE levels.  Free Space: $FREESPACE MB."
		echo $message | wall
		hostname=`hostname`
		if [ $EMAIL ]; then
			echo $message | mail -s "Compact failure on $hostname" $EMAIL
		fi
	fi
fi

# Increase count
i=$[$i+1]
echo $i > $CFG/compact.count

# END LOGIC
exit 0
