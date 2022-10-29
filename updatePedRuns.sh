#!/bin/bash -e
#
# updatePedRuns.sh:
#     This script is to be run as a cron job periodically to check for any new pedestal runs.
#

# Initial setup
curDir=$(pwd)
CMSSWVER=CMSSW_12_4_8
workDir=/nfshome0/chpapage/hcaloms/${CMSSWVER}/src/hcaloms
dataDir=${workDir}/data
localRunsDir=/data/hcaldqm/DQMIO/LOCAL
referenceFile=pedRuns_uploaded_new.dat
outputFile=pedsForUpload.dat
parameterFile=pedestals.par
DEBUG="false"

# Help statement
usage(){
    EXIT=$1

    echo -e "updatePedRuns.sh [options]\n"
    echo "-c [version]    CMSSW version. (default = ${CMSSWVER})"
    echo "-d              dry run option for testing. Runs the code without uploading to DB."
    echo "-h              display this message."

    exit "$EXIT"
}

# Process options
while getopts "c:dh" opt; do
    case "$opt" in
    c) CMSSWVER=$OPTARG
    ;;
    d) DEBUG="true"
    ;;
    h | *)
    usage 0
    exit 0
    ;;
    esac
done

# Print out all commands if debugging mode is on
if [[ "${DEBUG}" == "true" ]]; then
    set -x
fi

# Compare current list of runs with list of uploaded runs
pedRunsList=( "${localRunsDir}"/DQM_V0001_R000[1-9][0-9][0-9][1-9][0-9][0-9]__PEDESTAL__Commissioning2022__DQMIO.root )
# Run comm and keep only first column that contains new runs
readarray -t missingRuns < <( comm -23 <(printf "%s\n" "${pedRunsList[@]}") "${dataDir}/${referenceFile}" )

if [[ ${#missingRuns[@]} -eq 0 ]]; then
    echo "Nothing to update this time! Exiting..."
    exit 0
fi

# Set up the environment
# shellcheck source=/dev/null
source /opt/offline/cmsset_default.sh
cd "${workDir}"
eval "$(scramv1 runtime -sh)"
# shellcheck source=/dev/null
source envSetup.sh

# Get pedestals
if [ -f "${dataDir}/${outputFile}" ]; then
    rm "${dataDir}/${outputFile}"
fi
for run in "${missingRuns[@]}"; do
    if [ "$DEBUG" = "true" ]; then
        echo "[DEBUG]: python3 scripts/extractPED.py -f ${run} -z -t >> ${dataDir}/${outputFile}"
    fi
    python3 scripts/extractPED.py -f "${run}" -z -t >> "${dataDir}/${outputFile}"
done

if [ "$DEBUG" = "false" ]; then
    # Upload them to the database
    python3 scripts/dbuploader.py -f "${outputFile}" -p "${parameterFile}"
    # Update list of uploaded runs
    for run in "${missingRuns[@]}"; do
        echo "${run}" >> "${dataDir}/${referenceFile}"
    done
fi

# Return to initial directory
cd "${curDir}"
set +x
