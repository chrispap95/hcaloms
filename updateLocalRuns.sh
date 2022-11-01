#!/bin/bash -e
#
# updateLocalRuns.sh:
#     This script is to be run as a cron job periodically to check for any new local runs.
#

# Get the local setup
curDir=$(pwd)
# Move to script location
cd "$(dirname "$0")"
# shellcheck source=/dev/null
source envSetup.sh
echo "[updateLocalRuns.sh]: Setting working directory: ${WORKDIR}"

# Initial setup
localRunsDir=/data/hcaldqm/DQMIO/LOCAL
sqlQueryFile=${WORKDIR}/scripts/query.sql
referenceFile=${WORKDIR}/data/localRuns_uploaded.dat
outputFile=${WORKDIR}/data/localRunsForUpload.dat
parameterFile=${WORKDIR}/DBUtils/localRuns.par
ctlFile=${WORKDIR}/DBUtils/localRuns.ctl
logFile=${WORKDIR}/DBUtils/localRuns.log
badFile=${WORKDIR}/DBUtils/localRuns.bad
DEBUG="false"

# Help statement
usage(){
    EXIT=$1

    echo -e "updateLocalRuns.sh [options]\n"
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
localRunsList=( "${localRunsDir}"/DQM_V0001_R0003[0-9][0-9][1-9][0-9][0-9]__*__DQMIO.root )
# Run comm and keep only first column that contains new runs
readarray -t missingRuns < <( comm -23 <(printf "%s\n" "${localRunsList[@]}") <(sort ${referenceFile}) )

if [[ ${#missingRuns[@]} -eq 0 ]]; then
    echo "[updateLocalRuns.sh]: Nothing to update this time! Exiting..."
    exit 0
else
    echo "[updateLocalRuns.sh]: Will process ${#missingRuns[@]} run(s)."
fi

# Set up the environment
# shellcheck source=/dev/null
source /opt/offline/cmsset_default.sh
eval "$(scramv1 runtime -sh)"

# Process runs
if [ -f "${outputFile}" ]; then
    rm "${outputFile}"
fi
for run in "${missingRuns[@]}"; do
    # Do something with the runs
    runNumber="${run//${localRunsDir}\/DQM_V0001_R000/}"
    runNumber="${runNumber:0:6}"
    queryResult="$(
        sqlplus64 -S "${DB_CMS_RCMS_USR}"/"${DB_CMS_RCMS_PWD}"@cms_rcms @"${sqlQueryFile}" \
          STRING_VALUE CMS.HCAL_LEVEL_1:LOCAL_RUNKEY_SELECTED "${runNumber}"
    )"
    rsltLineNum="$(echo -n "${queryResult}" | grep -c '^')"
    queryResult="$(echo "${queryResult}" | tr '\n' '\t')"
    if [ "${rsltLineNum}" = 1 ]; then
        # This is result of the old type (pre run 3)
        echo -e "${runNumber}\t${queryResult}\t''" >> "${outputFile}"
    elif [ "${rsltLineNum}" = 3 ]; then
        # This is result of the new type (circa run 3)
        queryResult="$(echo -e "${queryResult}" | sed "s|true	||g" | sed "s|CEST|Europe/Zurich|g" | sed "s|CET|Europe/Zurich|g")"
        echo -e "${runNumber}\t${queryResult}" >> "${outputFile}"
    fi
done

# Upload them to the database and update the list of uploaded runs
# If debugging is on then just print out the command and the new runs
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

    python3 scripts/dbuploader.py -f "${outputFile}" -p "${parameterFile}"
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
