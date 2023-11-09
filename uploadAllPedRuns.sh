#!/bin/bash -e
#
# uploadAllPedRuns.sh
#     This script will upload all pedestals runs to the database.
#     Input:
#         - $1: CMSSW version
#         - $2: log directory
#

# Set the input variables
CMSSW_VERSION="$1"
LOG_DIR="$2"

# Get the directories of interest
CURRENT_DIR=$(pwd)
export WORK_DIR="${CURRENT_DIR}"
SCRIPT_DIR="$(dirname "$0")"
cd "${SCRIPT_DIR}"

# Set up the environment
# shellcheck source=/dev/null
source envSetup.sh

# Initial settings
localRunsDir=/data/hcaldqm/DQMIO/LOCAL
referenceFile=${SCRIPT_DIR}/data/pedRuns_uploaded.dat
outputFile=${SCRIPT_DIR}/data/pedsForUpload.dat
parameterFile=${SCRIPT_DIR}/DBUtils/pedestals.par
ctlFile=${SCRIPT_DIR}/DBUtils/pedestals.ctl
logFile=${SCRIPT_DIR}/DBUtils/pedestals.log
badFile=${SCRIPT_DIR}/DBUtils/pedestals.bad
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

# Set up CMSSW
echo -n "Setting up CMSSW: "
cd "${SCRIPT_DIR}"
# shellcheck source=/dev/null
source /opt/offline/cmsset_default.sh
CMSSW_PATH="../../CMSSW/${CMSSW_VERSION}"
cd "${CMSSW_PATH}/src"
eval "$(scramv1 runtime -sh)"
cd "${CURRENT_DIR}"
echo "ok"

# Get all pedestal runs
echo -n "Fetching ped runs: "
pedRunsList=(
    "${localRunsDir}"/DQM_V0001_R0003[0-9][0-9][0-9][0-9][0-9]__PEDESTAL__Commissioning202[2-5]__DQMIO.root
)
echo "ok"

# Print number of runs to process
TOTAL_STEPS=${#pedRunsList[@]}
echo "Will process ${TOTAL_STEPS} runs."

# Prepare the pedestal file
echo "Processing ped runs: "
if [ -f "${outputFile}" ]; then
    rm "${outputFile}"
fi

# Make a progress bar that keeps track of the progress
BAR_LENGTH=100
LAST_PERCENT=0
echo -ne 'Progress: ['
printf '%*s' $BAR_LENGTH
echo -ne "] 0%"
i=0
for run in "${pedRunsList[@]}"; do
    # Update the progress bar only when the percentage changes
    PERCENT=$((100 * (i + 1) / TOTAL_STEPS))
    if (( PERCENT != LAST_PERCENT )); then
        # Calculate how many '#' characters to print
        HASHES=$((BAR_LENGTH * (i + 1) / TOTAL_STEPS))

        # Prepare the progress bar string
        progressBar=""
        for ((j = 0; j < HASHES; j++)); do
            progressBar+="#"
        done

        # Print the progress bar
        printf '\rProgress: [%-*s] %d%%' "$BAR_LENGTH" "$progressBar" "$PERCENT"

        LAST_PERCENT=$PERCENT
    fi
    i=$(( i+1 ))

    # Run the pedestal script
    if [ "$DEBUG" = "true" ]; then
        echo "[DEBUG]: python3 scripts/extractPED.py -f ${run} -z -t >> ${outputFile}"
    fi
    python3 scripts/extractPED.py -f "${run}" -z -t >> "${outputFile}"
done
echo -e "\nDone!"

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
    DB_LOG_FILE="${LOG_DIR}/dbuploader.log"
    echo -n "Uploading pedestals to DB: "
    python3 scripts/dbuploader.py -f "${outputFile}" -p "${parameterFile}" -l "${DB_LOG_FILE}"
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
cd "${CURRENT_DIR}"
echo "All done!"
