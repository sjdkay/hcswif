#!/bin/bash

echo "Starting Replay script"
echo "I take as arguments the Run Number and max number of events!"
RUNNUMBER=$1
MAXEVENTS=-1
ROOTSTRING="Proton_coin_replay_production"
### Check you've provided the an argument
if [[ $1 -eq "" ]]; then
    echo "I need a Run Number!"
    echo "Please provide a run number as input"
    exit 2
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
UTILPATH="${REPLAYPATH}/UTIL_PROTON"
cd $REPLAYPATH
if [ ! -f "$REPLAYPATH/ROOTfiles/Scalers/coin_replay_scalers_${RUNNUMBER}_${MAXEVENTS}.root" ]; then
    eval "$REPLAYPATH/hcana -l -q \"SCRIPTS/COIN/SCALERS/replay_coin_scalers.C($RUNNUMBER,${MAXEVENTS})\""
    cd "$REPLAYPATH/CALIBRATION/bcm_current_map"
    root -b<<EOF 
.L ScalerCalib.C+
.x run.C("${REPLAYPATH}/ROOTfiles/Scalers/coin_replay_scalers_${RUNNUMBER}_${MAXEVENTS}.root")
.q  
EOF
    mv bcmcurrent_$RUNNUMBER.param $REPLAYPATH/PARAM/HMS/BCM/CALIB/bcmcurrent_$RUNNUMBER.param
    cd $REPLAYPATH
else echo "Scaler replayfile already found for this run in $REPLAYPATH/ROOTfiles/Scalers - Skipping scaler replay step"
fi
sleep 5
if [ ! -f "$REPLAYPATH/UTIL_PROTON/ROOTfiles/Analysis/ProtonLT/Proton_coin_replay_production_${RUNNUMBER}_${MAXEVENTS}.root" ]; then
    if [[ "${HOSTNAME}" != *"ifarm"* ]]; then
	eval "$REPLAYPATH/hcana -l -q \"UTIL_PROTON/scripts/replay/replay_production_coin.C($RUNNUMBER,$MAXEVENTS)\"" 
    elif [[ "${HOSTNAME}" == *"ifarm"* ]]; then
	eval "$REPLAYPATH/hcana -l -q \"UTIL_PROTON/scripts/replay/replay_production_coin.C($RUNNUMBER,$MAXEVENTS)\""| tee $REPLAYPATH/UTIL_PROTON/REPORT_OUTPUT/Analysis/ProtonLT/Proton_output_coin_production_${RUNNUMBER}_${MAXEVENTS}.report
    fi
else echo "Replayfile already found for this run in $REPLAYPATH/UTIL_PROTON/ROOTfiles/Analysis/ProtonLT/ - Skipping replay step"
fi
sleep 5
cd "$UTILPATH/scripts/CoinTimePeak"
if [ ! -f "$UTILPATH/OUTPUT/Analysis/ProtonLT/${RUNNUMBER}_{MAXEVENTS}_CTPeak_Data_HeepCoin.root" ]; then
    python3 $UTILPATH/scripts/CoinTimePeak/src/CoinTimePeak_HeepCoin.py ${ROOTSTRING} ${RUNNUMBER} ${MAXEVENTS} 
fi
sleep 5
root -b -l -q "${UTILPATH}/scripts/CoinTimePeak/PlotHeepCoinPeak.C(\"${RUNNUMBER}_-1_CTPeak_Data_HeepCoin.root\", \"${RUNNUMBER}_CTOut_HeepCoin\")"
exit 0
