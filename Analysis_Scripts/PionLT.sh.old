#!/bin/bash

### Stephen Kay, University of Regina
### 15/01/21
### stephen.kay@uregina.ca
### SJDK 11/01/22 - Stripped out large parts of the script, the script is calls instead does the same checks that this script previously did

echo "Starting Replay script"
echo "I take as arguments the Run Number and max number of events!"
RUNNUMBER=$1
MAXEVENTS=$2
### Check you've provided the an argument
if [[ -z "$1" ]]; then
    echo "I need a Run Number!"
    echo "Please provide a run number as input"
    exit 2
fi
if [[ -z "$2" ]]; then
    MAXEVENTS=-1
else
    MAXEVENTS=$2
fi

if [[ ${USER} = "cdaq" ]]; then
    echo "Warning, running as cdaq."
    echo "Please be sure you want to do this."
    echo "Comment this section out and run again if you're sure."
    exit 2
fi          

# Set path depending upon hostname. Change or add more as needed  
if [[ "${HOSTNAME}" = *"farm"* ]]; then  
    REPLAYPATH="/group/c-pionlt/online_analysis/hallc_replay_lt"
    if [[ "${HOSTNAME}" != *"ifarm"* ]]; then
	source /site/12gev_phys/softenv.sh 2.4
	source /apps/root/6.18.04/setroot_CUE.bash
    fi
    cd "$REPLAYPATH"
    source "$REPLAYPATH/setup.sh"
elif [[ "${HOSTNAME}" = *"qcd"* ]]; then
    REPLAYPATH="/group/c-pionlt/USERS/${USER}/hallc_replay_lt"
    source /site/12gev_phys/softenv.sh 2.4
    source /apps/root/6.18.04/setroot_CUE.bash
    cd "$REPLAYPATH"
    source "$REPLAYPATH/setup.sh" 
elif [[ "${HOSTNAME}" = *"cdaq"* ]]; then
    REPLAYPATH="/home/cdaq/hallc-online/hallc_replay_lt"
elif [[ "${HOSTNAME}" = *"phys.uregina.ca"* ]]; then
    REPLAYPATH="/home/${USER}/work/JLab/hallc_replay_lt"
fi
UTILPATH="${REPLAYPATH}/UTIL_PION"
cd $REPLAYPATH

echo "Running production analysis script - ${UTILPATH}/scripts/online_physics/PionLT/pion_prod_replay_analysis_sw.sh"
# This script does all of the checks as to whether the required files exists and so on
eval '"${UTILPATH}/scripts/online_physics/PionLT/pion_prod_replay_analysis_sw.sh" ${RUNNUMBER} ${MAXEVENTS}'

exit 0
