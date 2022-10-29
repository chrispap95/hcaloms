#!/bin/bash -e
#
# uploadAllLocalRuns.sh:
#     Script that will upload all local runs
#

# Initial settings
curDir=$(pwd)
CMSSWVER=CMSSW_12_4_8
workDir=/nfshome0/chpapage/hcaloms/${CMSSWVER}/src/hcaloms
dataDir=${workDir}/data
localRunsDir=/data/hcaldqm/DQMIO/LOCAL
sqlQueryFile="${workDir}/scripts/query.sql"
referenceFile=localRuns_uploaded.dat
outputFile=localRunsForUpload.dat
parameterFile=localRuns.par
ctlFile=localRuns.ctl
logFile=localRuns.log
badFile=localRuns.bad
DEBUG="false"

# Help statement
usage(){
    EXIT=$1

    echo -e "uploadAllLocalRuns.sh [options]\n"
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
runsList=( "${localRunsDir}"/DQM_V0001_R0003[0-9][0-9][0-9][0-9][0-9]__*__DQMIO.root )
echo "ok"

# Process runs
echo -n "Processing runs: "
if [ -f "${dataDir}/${outputFile}" ]; then
    rm "${dataDir}/${outputFile}"
fi
for run in "${runsList[@]}"; do
    # Do something with the runs
    runNumber="${run//${localRunsDir}\/DQM_V0001_R000/}"
    runNumber="${runNumber:0:6}"
    queryResult="$(sqlplus64 -S "${DB_CMS_RCMS_USR}"/"${DB_CMS_RCMS_PWD}"@cms_rcms @"${sqlQueryFile}" STRING_VALUE CMS.HCAL_LEVEL_1:LOCAL_RUNKEY_SELECTED "${runNumber}")"
    rsltLineNum="$(echo -n "${queryResult}" | grep -c '^')"
    queryResult="$(echo "${queryResult}" | tr '\n' '\t')"
    if [ "${rsltLineNum}" = 1 ]; then
        # This is result of the old type (pre run 3)
        echo -e "${runNumber}\t${queryResult}\t''" >> "${dataDir}/${outputFile}"
    elif [ "${rsltLineNum}" = 3 ]; then
        # This is result of the new type (circa run 3)
        queryResult="$(echo -e "${queryResult}" | sed "s|true	||g" | sed "s|CEST|Europe/Zurich|g" | sed "s|CET|Europe/Zurich|g")"
        echo -e "${runNumber}\t${queryResult}" >> "${dataDir}/${outputFile}"
    fi
done
echo "ok"

if [ "$DEBUG" = "false" ]; then
    # Generate .par file
    if [ -f "${workDir}/DBUtils/${parameterFile}" ]; then
        rm "${workDir}/DBUtils/${parameterFile}"
    fi
    {
        echo "userid=${DB_INT2R_USR}/${DB_INT2R_PWD}@int2r"
        echo "control=${workDir}/DBUtils/${ctlFile}"
        echo "log=${workDir}/DBUtils/${logFile}"
        echo "bad=${workDir}/DBUtils/${badFile}"
        echo "data=${dataDir}/${outputFile}"
        echo "direct=true"
    } >> "${workDir}/DBUtils/${parameterFile}"

    # Upload them to the database
    echo -n "Uploading pedestals to DB: "
    python3 scripts/dbuploader.py -f "${outputFile}" -p "${parameterFile}"
    echo "ok"

    # Update list of uploaded runs
    echo -n "Moving runs to the reference: "
    for run in "${runsList[@]}"; do
        echo "${run}" >> "${dataDir}/${referenceFile}"
    done
    echo "ok"
fi

# Return to initial directory
cd "${curDir}"
echo "All done!"
