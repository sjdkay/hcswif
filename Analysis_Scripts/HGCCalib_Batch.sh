#!/bin/bash

### Stephen Kay, University of Regina
### 13/01/21
### stephen.kay@uregina.ca

echo "Starting Replay script"
echo "I take as arguments the Run Number and max number of events!"
RUNNUMBER=$1
### Note - Due to the way the HGC calibration script works, it may need to chain runs together
### This script just processes a single run, users can chain together consecutive runs if they like, instructions on how to do this are printed
### after running the batch job submission script
### This script might be slightly redundant once the new calibration script suite is established
### Check you've provided the an argument
if [[ $1 -eq "" ]]; then
    echo "I need a Run Number!"
    echo "Please provide a run number as input"
    exit 2
fi
### Check if a second argument was provided, if not assume -1, if yes, this is max events
if [[ $2 -eq "" ]]; then
    MAXEVENTS=-1
else
    MAXEVENTS=$2
fi

#if [[ ${USER} = "cdaq" ]]; then
#    echo "Warning, running as cdaq."
#    echo "Please be sure you want to do this."
#    echo "Comment this section out and run again if you're sure."
#    exit 2
#fi          

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
cd $REPLAYPATH

# Create and use BCM calib for file if it doesn't exist
#if [ ! -f "$REPLAYPATH/ROOTfiles/Scalers/coin_replay_scalers_${RUNNUMBER}_150000.root" ]; then
#    eval "$REPLAYPATH/hcana -l -q \"SCRIPTS/COIN/SCALERS/replay_coin_scalers.C($RUNNUMBER,150000)\""
#    cd "$REPLAYPATH/CALIBRATION/bcm_current_map"
#    root -b<<EOF 
#.L ScalerCalib.C+
#.x run.C("${REPLAYPATH}/ROOTfiles/Scalers/coin_replay_scalers_${RUNNUMBER}_150000.root")
#.q  
#EOF
 #   mv bcmcurrent_$RUNNUMBER.param $REPLAYPATH/PARAM/HMS/BCM/CALIB/bcmcurrent_$RUNNUMBER.param
 #   cd $REPLAYPATH
#else echo "Scaler replayfile already found for this run in $REPLAYPATH/ROOTfiles/Scalers - Skipping scaler replay step"
#fi
#sleep 15
# Should use a slimmer replay script in future (def files here need slimming down)
if [ ! -f "$REPLAYPATH/ROOTfiles/Calib/HGC/coin_replay_production_${RUNNUMBER}_${MAXEVENTS}.root" ]; then
    if [[ "${HOSTNAME}" != *"ifarm"* ]]; then
	eval "$REPLAYPATH/hcana -l -q \"SCRIPTS/COIN/PRODUCTION/replay_production_coin_HGC.C($RUNNUMBER,$MAXEVENTS)\"" 
    elif [[ "${HOSTNAME}" == *"ifarm"* ]]; then
	eval 
	eval "$REPLAYPATH/hcana -l -q \"SCRIPTS/COIN/PRODUCTION/replay_production_coin_HGC.C($RUNNUMBER,$MAXEVENTS)\""
    fi
else echo "Replayfile already found for this run in $REPLAYPATH/ROOTfiles/Calib/HGC - Skipping replay step"
fi
sleep 15
cd "$REPLAYPATH/CALIBRATION/shms_hgcer_calib"
root -l -b -q "run_cal.C(\"coin_replay_production\", $MAXEVENTS, 1, $RUNNUMBER)" 
sleep 15
exit 0
