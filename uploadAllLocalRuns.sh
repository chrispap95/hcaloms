#!/bin/bash -e
#
# uploadAllLocalRuns.sh:
#     Script that will upload all local runs
#

# Get the local setup
curDir=$(pwd)
# shellcheck source=/dev/null
source envSetup.sh
echo "Setting working directory: ${WORKDIR}"

# Initial settings
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

# Initial setup
echo -n "Initial setup: "
cd "${WORKDIR}"
# shellcheck source=/dev/null
source /opt/offline/cmsset_default.sh
eval "$(scramv1 runtime -sh)"
echo "ok"

# Get all pedestal runs
echo -n "Fetching ped runs: "
runsList=( "${localRunsDir}"/DQM_V0001_R0003[0-9][0-9][0-9][0-9][0-9]__*__DQMIO.root )
echo "ok"

echo "Will process ${#runsList[@]} runs."

# Process runs
echo "Processing runs: "
if [ -f "${outputFile}" ]; then
    rm "${outputFile}"
fi
# Keeps track of the progress
i=0
for run in "${runsList[@]}"; do
    # Print out progress
    if [ $(( i % 100 )) -eq 0 ] && [ ${i} -gt 0 ]; then
        echo "Processed ${i} runs..."
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
    # For debugging
    if [ "$DEBUG" = "true" ] && [ $(( i % 10 )) -eq 0 ] && [ "${i}" -gt 0 ]; then
        echo "[DEBUG]: run=${run}, runNumber=${runNumber}, rsltLineNum=${rsltLineNum}, queryResult=${queryResult}"
    fi
done
echo "ok"

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
    echo -n "Uploading pedestals to DB: "
    python3 scripts/dbuploader.py -f "${outputFile}" -p "${parameterFile}"
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
cd "${curDir}"
echo "All done!"
