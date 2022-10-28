#!/bin/bash -e
#
# updateLocalRuns.sh:
#     This script is to be run as a cron job periodically to check for any new local runs.
#

# Initial setup
curDir=$(pwd)
CMSSWVER=CMSSW_12_4_8
workDir=/nfshome0/chpapage/hcaloms/${CMSSWVER}/src/hcaloms
dataDir=${workDir}/data
localRunsDir=/data/hcaldqm/DQMIO/LOCAL
referenceFile=localRuns_uploaded.dat
outputFile=localRunsForUpload.dat
parameterFile=localRuns.par
DEBUG="false"

# Help statement
usage(){
    EXIT=$1

    echo -e "updateLocalRuns.sh [options]\n"
    echo "-c [version]    CMSSW version. (default = ${CMSSWVER})"
    echo "-d              dry run option for testing. Runs the code without uploading to DB."
    echo "-h              display this message."

    exit $EXIT
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
localRunsList=( "${localRunsDir}/DQM_V0001_R000[1-9][0-9][0-9][1-9][0-9][0-9]_*_DQMIO.root" )
missingRuns=(\
    $(comm -3\
        <(echo ${localRunsList[@]} | sed "s| |\n|g" | sed "s|${localRunsDir}/||g")\
        <(cat "${dataDir}/${referenceFile}")\
    )\
)

# Set up the environment
source /opt/offline/cmsset_default.sh
cd "${workDir}"
eval `scramv1 runtime -sh`

# Upload them to the database and update the list of uploaded runs
# If debugging is on then just print out the command and the new runs
if [ "$DEBUG" = "false" ]; then
    python3 scripts/dbuploader.py -f "${outputFile}" -p "${parameterFile}"
    for run in ${missingRuns[@]}; do
        echo "${run}" >> "${dataDir}/${referenceFile}"
    done
else
    echo "[DEBUG]: python3 scripts/dbuploader.py -f ${outputFile} -p ${parameterFile}"
    echo "[DEBUG]: new runs to be added:"
    echo "${missingRuns}"
fi

# Return to initial directory
cd "${curDir}"
set +x
