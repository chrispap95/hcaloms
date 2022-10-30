#!/bin/bash -e
#
# uploadAllPedRuns.sh
#     Script that will upload all pedestals
#

# Initial settings
curDir=$(pwd)
CMSSWVER=CMSSW_12_4_8
workDir=/nfshome0/chpapage/hcaloms/${CMSSWVER}/src/hcaloms
localRunsDir=/data/hcaldqm/DQMIO/LOCAL
referenceFile=${workDir}/data/pedRuns_uploaded.dat
outputFile=${workDir}/data/pedsForUpload.dat
parameterFile=${workDir}/DBUtils/pedestals.par
ctlFile=${workDir}/DBUtils/pedestals.ctl
logFile=${workDir}/DBUtils/pedestals.log
badFile=${workDir}/DBUtils/pedestals.bad
DEBUG="false"

# Help statement
usage(){
    EXIT=$1

    echo -e "uploadAllPedRuns.sh [options]\n"
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

# Initial setup
echo -n "Initial setup: "
cd "${workDir}"
# shellcheck source=/dev/null
source /opt/offline/cmsset_default.sh
eval "$(scramv1 runtime -sh)"
# shellcheck source=/dev/null
source envSetup.sh
echo "ok"

# Get all pedestal runs
echo -n "Fetching ped runs: "
pedRunsList=( "${localRunsDir}"/DQM_V0001_R000[1-9][0-9][0-9][1-9][0-9][0-9]__PEDESTAL__Commissioning2022__DQMIO.root )
echo "ok"

# Extract pedestals
echo -n "Processing ped runs: "
if [ -f "${outputFile}" ]; then
    rm "${outputFile}"
fi
for run in "${pedRunsList[@]}"; do
    if [ "$DEBUG" = "true" ]; then
        echo -e "\n[DEBUG]: python3 scripts/extractPED.py -f ${run} -z -t >> ${outputFile}"
    fi
    python3 scripts/extractPED.py -f "${run}" -z -t >> "${outputFile}"
done
echo "ok"

if [ "$DEBUG" = "false" ]; then
    # Generate .par file
    if [ -f "${parameterFile}" ]; then
        rm "${parameterFile}"
    fi
    {
        echo "userid=${DB_INT2R_USR}/${DB_INT2R_PWD}@int2r"
        echo "control=${ctlFile}"
        echo "log=${logFile}"
        echo "bad=${badFile}"
        echo "data=${outputFile}"
        echo "direct=true"
    } >> "${parameterFile}"

    # Upload them to the database
    echo -n "Uploading pedestals to DB: "
    python3 scripts/dbuploader.py -f "${outputFile}" -p "${parameterFile}"
    echo "ok"

    # Update list of uploaded runs
    echo -n "Moving runs to the reference: "
    for run in "${pedRunsList[@]}"; do
        echo "${run}" >> "${referenceFile}"
    done
    echo "ok"
fi

# Return to initial directory
cd "${curDir}"
echo "All done!"
set +x
