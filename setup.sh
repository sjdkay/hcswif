#!/usr/bin/bash

# -----------------------------------------------------------------------------
#  Change these if this if not where hallc_replay and hcana live
export hcana_dir=/home/$USER/hcana
export hallc_replay_dir=/home/$USER/hallc_replay

# -----------------------------------------------------------------------------
#  Change if this gives you the wrong version of root, evio, etc
source /site/12gev_phys/softenv.sh 2.4

# -----------------------------------------------------------------------------
# Source setup scripts
curdir=`pwd`
cd $hcana_dir
source setup.sh
export PATH=$hcana_dir/bin:$PATH
echo Sourced $hcana_dir/setup.sh

cd $hallc_replay_dir
source setup.sh
echo Sourced $hallc_replay_dir/setup.sh

echo cd back to $curdir
cd $curdir

