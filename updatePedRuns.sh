#!/bin/bash -e
#
# updatePedRuns.sh:
#     This script will check if there are new pedestal runs and update the database if necessary.
#     A CMSSW envirnment should be already set up before running.
#     Input:
#         - $1: working directory
#         - $2: log file
#

# Input section
WORK_DIR="$1"
LOG_FILE="$2"

# Move to script location
cd "${WORK_DIR}"

# Initiate logging - if log file larger than 1 MB then recreate
export SCRIPT_LOG="${LOG_FILE}"
if [ -f "${SCRIPT_LOG}" ]; then
    LOG_SIZE="$(stat --printf='%s' "${SCRIPT_LOG}")"
    if [ "${LOG_SIZE}" -gt 1000000 ]; then
        rm "${SCRIPT_LOG}"
    fi
    touch "${SCRIPT_LOG}"
else
    touch "${SCRIPT_LOG}"
fi
SCRIPTENTRY
INFO "Setting working directory: ${WORK_DIR}"

# Initial setup
localRunsDir=/data/hcaldqm/DQMIO/LOCAL
referenceFile=${WORK_DIR}/data/pedRuns_uploaded.dat
outputFile=${WORK_DIR}/data/pedsForUpload.dat
parameterFile=${WORK_DIR}/DBUtils/pedestals.par
ctlFile=${WORK_DIR}/DBUtils/pedestals.ctl
logFile=${WORK_DIR}/DBUtils/pedestals.log
badFile=${WORK_DIR}/DBUtils/pedestals.bad
dbgOn="false"

# Help statement
usage(){
    EXITUSAGE=$1

    echo -e "updatePedRuns.sh [options]\n"
    echo "-d              dry run option for testing. Runs the code without uploading to DB."
    echo "-h              display this message."

    SCRIPTEXIT
    exit "$EXITUSAGE"
}

# Process options
while getopts "dh" opt; do
    case "$opt" in
    d) dbgOn="true"
    ;;
    h | *)
    usage 0
    ;;
    esac
done

# Compare current list of runs with list of uploaded runs
pedRunsList=(
    "${localRunsDir}"/DQM_V0001_R0003[0-9][0-9][0-9][0-9][0-9]__PEDESTAL__Commissioning202[2-5]__DQMIO.root
)
# Run comm and keep only first column that contains new runs
readarray -t missingRuns < <( comm -23 <(printf "%s\n" "${pedRunsList[@]}") <(sort "${referenceFile}") )

if [[ ${#missingRuns[@]} -eq 0 ]]; then
    INFO "Nothing to update this time! Exiting..."
    SCRIPTEXIT
    return
else
    INFO "Will process ${#missingRuns[@]} run(s)."
fi

# Get pedestals
if [ -f "${outputFile}" ]; then
    rm "${outputFile}"
fi
for run in "${missingRuns[@]}"; do
    if [ "$dbgOn" = "true" ]; then
        DEBUG "python3 scripts/extractPED.py -f ${run} -z -t >> ${outputFile}"
    fi
    python3 scripts/extractPED.py -f "${run}" -z -t >> "${outputFile}"
done

if [ "$dbgOn" = "false" ]; then
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
    python3 scripts/dbuploader.py -f "${outputFile}" -p "${parameterFile}" -l "${DB_LOG_FILE}"
    # Update list of uploaded runs
    for run in "${missingRuns[@]}"; do
        echo "${run}" >> "${referenceFile}"
    done
else
    DEBUG "python3 scripts/dbuploader.py -f ${outputFile} -p ${parameterFile}"
    DEBUG "new runs to be added:"
    DEBUG "${missingRuns[@]}"
fi

SCRIPTEXIT
