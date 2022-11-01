#!/bin/bash -e
#
# uploadAllPedRuns.sh
#     Script that will upload all pedestals
#

# Get the local setup
curDir=$(pwd)
# shellcheck source=/dev/null
source envSetup.sh
echo "Setting working directory: ${WORKDIR}"

# Initial settings
localRunsDir=/data/hcaldqm/DQMIO/LOCAL
referenceFile=${WORKDIR}/data/pedRuns_uploaded.dat
outputFile=${WORKDIR}/data/pedsForUpload.dat
parameterFile=${WORKDIR}/DBUtils/pedestals.par
ctlFile=${WORKDIR}/DBUtils/pedestals.ctl
logFile=${WORKDIR}/DBUtils/pedestals.log
badFile=${WORKDIR}/DBUtils/pedestals.bad
DEBUG="false"

# Help statement
usage(){
    EXIT=$1

    echo -e "uploadAllPedRuns.sh [options]\n"
    echo "-d              dry run option for testing. Runs the code without uploading to DB."
    echo "-h              display this message."

    exit "$EXIT"
}

# Process options
while getopts "dh" opt; do
    case "$opt" in
    d) DEBUG="true"
    ;;
    h | *)
    usage 0
    ;;
    esac
done

# Initial setup
echo -n "Initial setup: "
cd "${WORKDIR}"
# shellcheck source=/dev/null
source /opt/offline/cmsset_default.sh
eval "$(scramv1 runtime -sh)"
echo "ok"

# Get all pedestal runs
echo -n "Fetching ped runs: "
pedRunsList=( "${localRunsDir}"/DQM_V0001_R000[1-9][0-9][0-9][1-9][0-9][0-9]__PEDESTAL__Commissioning2022__DQMIO.root )
echo "ok"

# Print number of runs to process
echo "Will process ${#pedRunsList[@]} runs."

# Extract pedestals
echo "Processing ped runs: "
if [ -f "${outputFile}" ]; then
    rm "${outputFile}"
fi
# Keeps track of the progress
i=0
for run in "${pedRunsList[@]}"; do
    # Print out progress
    if [ $(( i % 100 )) -eq 0 ] && [ ${i} -gt 0 ]; then
        echo "Processed ${i} runs..."
    fi
    i=$(( i+1 ))
    if [ "$DEBUG" = "true" ]; then
        echo "[DEBUG]: python3 scripts/extractPED.py -f ${run} -z -t >> ${outputFile}"
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
    echo -n "Recreating the runs reference file: "
        if [ -f "${referenceFile}" ]; then
        rm "${referenceFile}"
    fi
    for run in "${pedRunsList[@]}"; do
        echo "${run}" >> "${referenceFile}"
    done
    echo "ok"
fi

# Return to initial directory
cd "${curDir}"
echo "All done!"
