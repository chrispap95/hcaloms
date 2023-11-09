#!/bin/bash -e
#
# uploadAllPedRuns.sh
#     This script will upload all pedestals runs to the database.
#     Input:
#         - $1: CMSSW version
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
sqlQueryFile=${SCRIPT_DIR}/scripts/query.sql
referenceFile=${SCRIPT_DIR}/data/localRuns_uploaded.dat
outputFile=${SCRIPT_DIR}/data/localRunsForUpload.dat
parameterFile=${SCRIPT_DIR}/DBUtils/localRuns.par
ctlFile=${SCRIPT_DIR}/DBUtils/localRuns.ctl
logFile=${SCRIPT_DIR}/DBUtils/localRuns.log
badFile=${SCRIPT_DIR}/DBUtils/localRuns.bad
DEBUG="false"

# Help statement
usage(){
    EXIT=$1

    echo -e "uploadAllLocalRuns.sh [options]\n"
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
runsList=( "${localRunsDir}"/DQM_V0001_R0003[0-9][0-9][0-9][0-9][0-9]__*__DQMIO.root )
echo "ok"

# Print number of runs to process
TOTAL_STEPS=${#runsList[@]}
echo "Will process ${#runsList[@]} runs."

# Process runs
echo "Processing runs: "
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
for run in "${runsList[@]}"; do
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

    # Do something with the runs
    runNumber="${run//${localRunsDir}\/DQM_V0001_R000/}"
    runNumber="${runNumber:0:6}"
    # Skip first runs that don't give query results. Great speedup.
    if [ "${runNumber}" -lt 311915 ]; then
        continue
    fi
    queryResult="$(
        sqlplus64 -S "${DB_CMS_RCMS_USR}"/"${DB_CMS_RCMS_PWD}"@cms_rcms \
            @"${sqlQueryFile}" "${runNumber}"
    )"
    if [[ -z "${queryResult}" ]]; then
        rsltLineNum=0
    else
        rsltLineNum="$(echo -n "${queryResult}" | grep -c '^')"
    fi
    queryResult="$(echo "${queryResult}" | tr '\n' '\t')"
    if [ "${rsltLineNum}" = 1 ]; then
        # This is result of the old type (pre run 3)
        echo -e "${runNumber}\t${queryResult}\t''" >> "${outputFile}"
    elif [ "${rsltLineNum}" = 2 ]; then
        # This is result of the new type (circa run 3)
        queryResult="$(
            echo -e "${queryResult}" | sed "s|CEST|Europe/Zurich|g" | sed "s|CET|Europe/Zurich|g"
        )"
        echo -e "${runNumber}\t${queryResult}" >> "${outputFile}"
    fi
    # For debugging
    if [ "$DEBUG" = "true" ] && [ $(( i % 10 )) -eq 0 ] && [ "${i}" -gt 0 ]; then
        echo -n "[DEBUG]: run=${run}, runNumber=${runNumber}, "
        echo "rsltLineNum=${rsltLineNum}, queryResult=${queryResult}"
    fi
done
echo -e "\nDone!"

if [ "$DEBUG" = "true" ]; then
    echo "[DEBUG]: the script would normally upload $(wc -l "${outputFile}") runs to the DB."
fi

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
    echo -n "Uploading runs to DB: "
    python3 scripts/dbuploader.py -f "${outputFile}" -p "${parameterFile}" -l "${DB_LOG_FILE}"
    echo "ok"

    # List of uploaded runs will be recreated
    echo -n "Moving runs to the reference: "
    if [ -f "${referenceFile}" ]; then
        rm "${referenceFile}"
    fi
    for run in "${runsList[@]}"; do
        echo "${run}" >> "${referenceFile}"
    done
    echo "ok"
fi

# Return to initial directory
cd "${CURRENT_DIR}"
echo "All done!"
