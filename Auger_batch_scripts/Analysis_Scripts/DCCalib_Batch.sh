#!/bin/bash

### Stephen Kay --- University of Regina --- 12/11/19 ###
### Script for running (via batch or otherwise) the DC calibration, this one script does all of the relevant steps for the calibration process
### REQUIRES two arguments, runnumber and spectrometer (HMS or SHMS, the caps are important!)
### If you want to run with LESS than all of the events, provide a third argument with # events

### SK 30/03/21 - This version is updated to be a bit more flexible, the old version assumed only 4 sets of param files would be used as was the case from the online running

RUNNUMBER=$1
OPT=$2
### Check you've provided the first argument
if [[ $1 -eq "" ]]; then
    echo "I need a Run Number!"
    echo "Please provide a run number as input"
    exit 2
fi
### Check you have provided the second argument correctly
if [[ ! $2 =~ ^("HMS"|"SHMS")$ ]]; then
    echo "Please specify spectrometer, HMS or SHMS"
    exit 2
fi
### Check if a third argument was provided, if not assume -1, if yes, this is max events
if [[ $3 -eq "" ]]; then
    MAXEVENTS=-1
else
    MAXEVENTS=$3
fi
if [[ $OPT == "HMS" ]]; then
    spec="hms"
    specL="h"
    elif [[ $OPT == "SHMS" ]]; then
    spec="shms"
    specL="p"
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
    cd "/group/c-pionlt/hcana/"
    source "/group/c-pionlt/hcana/setup.sh"
    cd "$REPLAYPATH"
    source "$REPLAYPATH/setup.sh"
elif [[ "${HOSTNAME}" = *"qcd"* ]]; then
    REPLAYPATH="/group/c-pionlt/USERS/${USER}/hallc_replay_lt"
    source /site/12gev_phys/softenv.sh 2.4
    source /apps/root/6.18.04/setroot_CUE.bash
    cd "/group/c-pionlt/hcana/"
    source "/group/c-pionlt/hcana/setup.sh" 
    cd "$REPLAYPATH"
    source "$REPLAYPATH/setup.sh" 
elif [[ "${HOSTNAME}" = *"cdaq"* ]]; then
    REPLAYPATH="/home/cdaq/pionLT-2021/hallc_replay_lt"
elif [[ "${HOSTNAME}" = *"phys.uregina.ca"* ]]; then
    REPLAYPATH="/home/${USER}/work/JLab/hallc_replay_lt"
fi
cd $REPLAYPATH

### Check the extra folders you'll need exist, if they don't then make them
if [ ! -d "$REPLAYPATH/DBASE/COIN/HMS_DCCalib" ]; then
    mkdir "$REPLAYPATH/DBASE/COIN/HMS_DCCalib"
fi

if [ ! -d "$REPLAYPATH/DBASE/COIN/SHMS_DCCalib" ]; then
    mkdir "$REPLAYPATH/DBASE/COIN/SHMS_DCCalib"
fi

if [ ! -d "$REPLAYPATH/PARAM/HMS/DC/CALIB" ]; then
    mkdir "$REPLAYPATH/PARAM/HMS/DC/CALIB"
fi

if [ ! -d "$REPLAYPATH/PARAM/SHMS/DC/CALIB" ]; then
    mkdir "$REPLAYPATH/PARAM/SHMS/DC/CALIB"
fi

### Run the first replay script, then, run the calibration macro
### The first script uses a param file that uses "tzero per wire" set to 0 in the h/pdc cuts file
ROOTFILE="$REPLAYPATH/ROOTfiles/Calib/DC/"$OPT"_DC_Calib_Pt1_"$RUNNUMBER"_"$MAXEVENTS".root" 
if [[ ! -f "${ROOTFILE}" ]]; then
    eval "$REPLAYPATH/hcana -l -q \"SCRIPTS/COIN/CALIBRATION/"$OPT"DC_Calib_Coin_Pt1.C($RUNNUMBER,$MAXEVENTS)\""
else echo "Pt1 Replay file already found at - ${ROOTFILE} - skipping Pt1 replay"
fi
cd "$REPLAYPATH/CALIBRATION/dc_calib/scripts"
root -l -b -q "$REPLAYPATH/CALIBRATION/dc_calib/scripts/main_calib.C(\"$OPT\", \"$ROOTFILE\", $RUNNUMBER)"

### Loop checks if the new parameter files exist, returns an error if they don't
if [[ ! -f "$REPLAYPATH/CALIBRATION/dc_calib/scripts/"$OPT"_DC_cardLog_"$RUNNUMBER"/"$specL"dc_calib_"$RUNNUMBER$".param" && ! -f  "$REPLAYPATH/CALIBRATION/dc_calib/scripts/"$OPT"_DC_cardLog_"$RUNNUMBER"/"$specL"dc_tzero\
_per_wire_"$RUNNUMBER$".param" ]]; then
    echo "New parameter files not found, calibration script likely failed"
    exit 2
fi

### Copy our new parameter files to another directory
cp "$REPLAYPATH/CALIBRATION/dc_calib/scripts/"$OPT"_DC_cardLog_"$RUNNUMBER"/"$specL"dc_calib_"$RUNNUMBER$".param" "$REPLAYPATH/PARAM/"$OPT"/DC/CALIB/"$specL"dc_calib_"$RUNNUMBER$".param"
cp "$REPLAYPATH/CALIBRATION/dc_calib/scripts/"$OPT"_DC_cardLog_"$RUNNUMBER"/"$specL"dc_tzero_per_wire_"$RUNNUMBER$".param" "$REPLAYPATH/PARAM/"$OPT"/DC/CALIB/"$specL"dc_tzero_per_wire_"$RUNNUMBER$".param"
cd "$REPLAYPATH/DBASE/COIN"

# Need to find the DBASE file used in the previous replay, do this from the replay script used
REPLAYSCRIPT1="${REPLAYPATH}/SCRIPTS/COIN/CALIBRATION/${OPT}DC_Calib_Coin_Pt1.C"
while IFS='' read -r line || [[ -n "$line" ]]; do
    if [[ $line =~ "//" ]]; then continue;
    elif [[ $line =~ "gHcParms->AddString(\"g_ctp_database_filename\"," ]]; then
	tmpstring=$(echo $line| cut -d "," -f2) # This is the path to the DBase file but with some junk in the string
	tmpstring2=$(echo $tmpstring | sed 's/[");]//g') # Sed command to strip junk (", ) or ; ) from the string
	BASE_DBASEFILE="${REPLAYPATH}/${tmpstring2}"
    fi
done < "$REPLAYSCRIPT1" 

# Need to find the param file used in the previous replay, do this from provided runnumber and the database file
# This could probably be simplified slightly, but basically it finds the right "block" and sets a flag to pick up the NEXT param file listed
TestingVar=$((0))
while IFS='' read -r line || [[ -n "$line" ]]; do
    # If the line in the file is blank, contains a hash or has g_ctp in it, skip it, only leaves the lines which contain the run numbe ranges
    if [ -z "$line" ] ; then continue;
    elif [[ $line =~ "#" ]]; then continue;
    elif [[ $line =~ "g_ctp_kin" ]]; then continue;
    elif [[ $line != *"g_ctp_par"* ]]; then #If line is NOT the one specifying the param file, then get the run numbers
	# Starting run number is just the field before the - delimiter (f1), ending run number is the one after (f2)
	# -d specifies the delimiter which is the term in speech marks
	RunStart=$(echo $line| cut -d "-" -f1)
	RunEnd=$(echo $line| cut -d "-" -f2)
	if [ "$RUNNUMBER" -ge "$RunStart" -a "$RUNNUMBER" -le "$RunEnd" ]; then
	    TestingVar=$((1)) # If run number in range, set testing var to 1
	else TestingVar=$((0)) # If not in range, set var to 0
	fi
    elif [[ $line =~ "g_ctp_par" ]]; then
	if [ $TestingVar == 1 ]; then
	    tmpstring3=$(echo $line| cut -d "=" -f2) # tmpstrings could almost certainly be combined into one expr
	    BASE_PARAMFILE=$(echo $tmpstring3 | sed 's/["]//g')
	    BASE_PARAMFILE_PATH="${REPLAYPATH}/${BASE_PARAMFILE}"
	else continue
	fi
    fi
done < "$BASE_DBASEFILE"

# Now have base DBASE and PARAM files, copy these to a new directory and edit them with newly generated param files
# Check files exist first, if they do, copy them and proceed
if [[ ! -f "$BASE_DBASEFILE" || ! -f "$BASE_PARAMFILE_PATH" ]]; then
    echo "Base DBASE or param file not found, check -"
    echo "$BASE_DBASEFILE"
    echo "and"
    echo "$BASE_PARAMFILE_PATH"
    echo "exist. Modify script accordingly."
    exit 3
fi

#echo "Copying $BASE_DBASEFILE and $BASE_PARAMFILE_PATH to ${OPT}_DCCalib"
cp "$BASE_DBASEFILE" "${REPLAYPATH}/DBASE/COIN/${OPT}_DCCalib/standard_${RUNNUMBER}.database"
cp "$BASE_PARAMFILE_PATH" "${REPLAYPATH}/DBASE/COIN/${OPT}_DCCalib/general_${RUNNUMBER}.param"

# Switch out the param file called in the dbase file
# Sed command looks a bit different, need to use different quote/delimiters as variable uses / and so on
sed -i 's|'"$BASE_PARAMFILE"'|'"DBASE/COIN/${OPT}_DCCalib/general_$RUNNUMBER.param"'|' "${REPLAYPATH}/DBASE/COIN/${OPT}_DCCalib/standard_${RUNNUMBER}.database"

# Depending upon spectrometer, switch out the relevant files in the param file
if [[ $OPT == "HMS" ]]; then
    sed -i "s/hdc_calib.*/CALIB\/hdc_calib_${RUNNUMBER}.param\"/" "${REPLAYPATH}/DBASE/COIN/${OPT}_DCCalib/general_${RUNNUMBER}.param"
    sed -i "s/hdc_tzero_per_wire.*/CALIB\/hdc_tzero_per_wire_${RUNNUMBER}.param\"/" "${REPLAYPATH}/DBASE/COIN/${OPT}_DCCalib/general_${RUNNUMBER}.param"
elif [[ $OPT == "SHMS" ]]; then
    sed -i "s/pdc_calib.*/CALIB\/pdc_calib_${RUNNUMBER}.param\"/" "${REPLAYPATH}/DBASE/COIN/${OPT}_DCCalib/general_${RUNNUMBER}.param"
    sed -i "s/pdc_tzero_per_wire.*/CALIB\/pdc_tzero_per_wire_${RUNNUMBER}.param\"/" "${REPLAYPATH}/DBASE/COIN/${OPT}_DCCalib/general_${RUNNUMBER}.param"
fi

# This is a temporary (and crappy) solution, where we force the cuts.param file specified back to whatever it is in standard.database (hdc_cuts.param and pdc_cuts.param are sym links so this should be fine)
sed -i "hdc_cuts.*/hdc_cuts.param/" "${REPLAYPATH}/DBASE/COIN/${OPT}_DCCalib/general_${RUNNUMBER}.param"    
sed -i "pdc_cuts.*/pdc_cuts.param/" "${REPLAYPATH}/DBASE/COIN/${OPT}_DCCalib/general_${RUNNUMBER}.param"

### Finally, replay again with our new parameter files
cd $REPLAYPATH
eval "$REPLAYPATH/hcana -l -q \"SCRIPTS/COIN/CALIBRATION/"$OPT"DC_Calib_Coin_Pt2.C($RUNNUMBER,$MAXEVENTS)\""
cd "$REPLAYPATH/CALIBRATION/dc_calib/Calibration_Checker/"
root -b << EOF
.x run_DC_Calib_Check.C(${RUNNUMBER}, ${MAXEVENTS}, "${OPT}")
.q
EOF

exit 0
