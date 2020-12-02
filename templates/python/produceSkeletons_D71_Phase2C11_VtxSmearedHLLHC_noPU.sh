#!/bin/sh

# intended for developments in CMSSW_11_2_0 cycle


# This is the shell script that will generate all the skeletons using cmsDriver commands.
# The commands included have been taken from runTheMatrix with the following command:
#
# runTheMatrix.py -w upgrade -l 20634.0 --command="--no_exec" --dryRun
#
# The reconstruction as part of the ticl framework is injected into the RECO_fragment.
#
# For all commands remove --filein and --fileout options.
# Add python_filename option
#
# The first command combines step1 and step2 (GSD):
# - mix in pileup
# - run up to DIGI...HLT:@fake2
# The following changes are implemented on top:
# --beamspot HLLHC14TeV ➜ --beamspot NoSmear
# --eventcontent FEVTDEBUG ➜ --eventcontent FEVTDEBUGHLT
# Removed --relval option.
#
# The second command is step3 removing overlap with step2 (RECO):
# - remove pileup part
# - remove MINIAODSIM from event content and data tier
# - remove PAT from steps (-s)
# - remove @miniAODValidation from VALIDATION step
# - remove @miniAODDQM from DQM step
#
# The third command is a copy of the second only re-running RECO (for NTUP):
# - remove DQM from event content
# - remove DQMIO from data tier
# - add --processName=NTUP option
#
# Those commands should be regularly checked and, in case of changes, propagated into this script!

action() {
  # default arguments
  local inject_ticl="0"
  local geometry="Extended2026D71"
  local custom="--customise Configuration/DataProcessing/Utils.addMonitoring"
  local tag=""

  # parse arguments
  for arg in "$@"; do
    if [ "$arg" = ^"ticl" ]; then
      inject_ticl="1"
    elif [ "$arg" = ^"no-ticl" ]; then
      inject_ticl="0"
    elif [[ $arg =~ ^"geometry" ]]; then        
        geometry=${arg/geometry=/}
        echo "Geometry will be modified to $geometry"
    elif [[ $arg =~ ^"tag" ]]; then        
        tag=_${arg/tag=/}
        echo "Fragments wil be tagged with ${tag}"
    elif [[ $arg =~ ^"custom" ]]; then        
        custom=${arg/custom=/}
        echo "Custom options $custom"
    elif [[ $arg =~ ^"pileup_input" ]]; then
        pileup_input=${arg/pileup_input=/}
        #if das is not given try to build the list of files by listing the local directory given
        echo "Pileup input modified to ${pileup_input}"
    else
      2>&1 echo "unknown argument: $arg"
      return "1"
    fi
  done


  cmsDriver.py TTbar_14TeV_TuneCUETP8M1_cfi \
      --conditions auto:phase2_realistic_T15 \
      -n 100 \
      --era Phase2C11 \
      --eventcontent FEVTDEBUGHLT \
      -s GEN,SIM,DIGI:pdigi_valid,L1,L1TrackTrigger,DIGI2RAW,HLT:@fake2 \
      --datatier GEN-SIM \
      --beamspot HLLHC14TeV \
      ${custom} \
      --geometry ${geometry} \
      --fileout GSD.root \
      --no_exec \
      --python_filename=GSD_fragment${tag}.py
  

  cmsDriver.py step3 \
    --conditions auto:phase2_realistic_T15 \
    -n -1 \
    --era Phase2C11 \
    --eventcontent FEVTDEBUGHLT,DQM \
    -s RAW2DIGI,L1Reco,RECO,RECOSIM,VALIDATION:@phase2Validation,DQM:@phase2 \
    --datatier GEN-SIM-RECO,DQMIO \
    --geometry ${geometry} \
    --fileout RECO.root \
    --no_exec \
    --python_filename=RECO_fragment${tag}.py


  if [ "$inject_ticl" = "1" ]; then
    echo -e "\ninject ticl into RECO_fragment${tag}.py"
    ./inject_ticl.sh RECO_fragment${tag}.py
    if [ "$?" = "0" ]; then
      echo
    else
      2>&1 echo "ticl injection failed"
      return "2"
    fi
  fi


  cmsDriver.py step3 \
    --conditions auto:phase2_realistic_T15 \
    -n -1 \
    --era Phase2C11 \
    --eventcontent FEVTDEBUGHLT \
    -s RAW2DIGI,L1Reco,RECO,RECOSIM \
    --datatier GEN-SIM-RECO \
    --geometry ${geometry} \
    --fileout NTUP.root \
    --no_exec \
    --processName=NTUP \
    --python_filename=NTUP_fragment${tag}.py
}
action "$@"