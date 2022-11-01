#!/bin/bash -e
#
# updatePedRuns.sh:
#     This script is to be run as a cron job periodically to check for any new pedestal runs.
#

# Get the local setup
curDir=$(pwd)
# Move to script location
cd "$(dirname "$0")"
# shellcheck source=/dev/null
source envSetup.sh
echo "Setting working directory: ${WORKDIR}"

# Initial setup
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

    echo -e "updatePedRuns.sh [options]\n"
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

# Compare current list of runs with list of uploaded runs
pedRunsList=( "${localRunsDir}"/DQM_V0001_R000[1-9][0-9][0-9][1-9][0-9][0-9]__PEDESTAL__Commissioning2022__DQMIO.root )
# Run comm and keep only first column that contains new runs
readarray -t missingRuns < <( comm -23 <(printf "%s\n" "${pedRunsList[@]}") "${referenceFile}" )

if [[ ${#missingRuns[@]} -eq 0 ]]; then
    echo "Nothing to update this time! Exiting..."
    exit 0
else
    echo "Will process ${#missingRuns[@]} run(s)."
fi

# Set up the environment
# shellcheck source=/dev/null
source /opt/offline/cmsset_default.sh
eval "$(scramv1 runtime -sh)"

# Get pedestals
if [ -f "${outputFile}" ]; then
    rm "${outputFile}"
fi
for run in "${missingRuns[@]}"; do
    if [ "$DEBUG" = "true" ]; then
        echo "[DEBUG]: python3 scripts/extractPED.py -f ${run} -z -t >> ${outputFile}"
    fi
    python3 scripts/extractPED.py -f "${run}" -z -t >> "${outputFile}"
done

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
    python3 scripts/dbuploader.py -f "${outputFile}" -p "${parameterFile}"
    # Update list of uploaded runs
    for run in "${missingRuns[@]}"; do
        echo "${run}" >> "${referenceFile}"
    done
else
    echo "[DEBUG]: python3 scripts/dbuploader.py -f ${outputFile} -p ${parameterFile}"
    echo "[DEBUG]: new runs to be added:"
    echo "${missingRuns[@]}"
fi

# Return to initial directory
cd "${curDir}"
