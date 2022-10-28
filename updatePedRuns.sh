#!/bin/bash -e
#
# This script is to be run as a cron job periodically to check for any new pedestal runs.
#

# Initial setup
curDir=$(pwd)
cmssw=$1
workDir=/nfshome0/chpapage/hcaloms/${cmssw}/src/hcaloms
dataDir=${workDir}/data
localRunsDir=/data/hcaldqm/DQMIO/LOCAL
referenceFile=pedRuns_uploaded.dat
outputFile=pedsForUpload.dat
parameterFile=pedestals.par

# Compare current list of runs with list of uploaded runs
pedRunsList=( "${localRunsDir}/DQM_V0001_R000[1-9][0-9][0-9][1-9][0-9][0-9]__PEDESTAL__Commissioning2022__DQMIO.root" )
missingRuns=(\
    $(comm -3\
        <(echo "${pedRunsList[@]}" | sed "s| |\n|g" | sed "s|${localRunsDir}/||g")\
        <(cat "${dataDir}/${referenceFile}")\
    )\
)

# Set up the environment
# shellcheck source=/dev/null
source /opt/offline/cmsset_default.sh
cd "${workDir}"
eval "$(scramv1 runtime -sh)"

# Get pedestals
if [ -f "${dataDir}/${outputFile}" ]; then
    rm "${dataDir}/${outputFile}"
fi
for run in "${missingRuns[@]}"; do
    python3 scripts/extractPED.py -f "${run}" -z -t >> "${dataDir}/${outputFile}"
done

# Upload them to the database
python3 scripts/dbuploader.py -f "${outputFile}" -p "${parameterFile}"

# Update list of uploaded runs
for run in "${missingRuns[@]}"; do
    echo "${run}" >> "${dataDir}/${referenceFile}"
done

# Return to initial directory
cd "${curDir}"
