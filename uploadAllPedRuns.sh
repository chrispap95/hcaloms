#!/bin/bash -e
#
# Script that will upload all pedestals
#

# Initial settings
curDir=$(pwd)
workDir=/nfshome0/chpapage/hcaloms/CMSSW_12_4_8/src/hcaloms
dataDir=${workDir}/data
localRunsDir=/data/hcaldqm/DQMIO/LOCAL
referenceFile=pedRuns_uploaded.dat
outputFile=pedsForUpload.dat
parameterFile=pedestals.par

# Initial setup
echo -n "Initial setup: "
cd "${workDir}"
# shellcheck source=/dev/null
source /opt/offline/cmsset_default.sh
eval "$(scramv1 runtime -sh)"
echo "ok"

# Get all pedestal runs
echo -n "Fetching ped runs: "
pedRunsList=( "${localRunsDir}/DQM_V0001_R000[1-9][0-9][0-9][1-9][0-9][0-9]__PEDESTAL__Commissioning2022__DQMIO.root" )
echo "ok"

# Extract pedestals
echo -n "Processing ped runs: "
if [ -f "${dataDir}/${outputFile}" ]; then
    rm "${dataDir}/${outputFile}"
fi
for run in ${pedRunsList[@]}; do
    python3 scripts/extractPED.py -f "${run}" -z -t >> "${dataDir}/${outputFile}"
done
echo "ok"

# Upload them to the database
echo -n "Uploading pedestals to DB: "
python3 scripts/dbuploader.py -f "${outputFile}" -p "${parameterFile}"
echo "ok"

# Update list of uploaded runs
echo -n "Moving runs to the reference: "
for run in ${missingRuns[@]}; do
    echo "${run}" >> "${dataDir}/${referenceFile}"
done
echo "ok"

# Return to initial directory
cd "${curDir}"
echo "All done!"
