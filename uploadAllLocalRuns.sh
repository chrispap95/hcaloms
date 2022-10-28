#!/bin/bash -e
#
# Script that will upload all runs
#

# Initial settings
curDir="$(pwd)"
workDir=/nfshome0/chpapage/hcaloms/CMSSW_12_4_8/src/hcaloms
dataDir="${workDir}/data"
localRunsDir=/data/hcaldqm/DQMIO/LOCAL
sqlQueryFile="${workDir}/scripts/query.sql"
referenceFile=runs_uploaded.dat
outputFile=runsForUpload.dat
parameterFile=runs.par

# Initial setup
echo -n "Initial setup: "
cd "${workDir}"
# shellcheck source=/dev/null
source /opt/offline/cmsset_default.sh
eval "$(scramv1 runtime -sh)"
echo "ok"

# Get all pedestal runs
echo -n "Fetching ped runs: "
runsList=( "${localRunsDir}/DQM_V0001_R0003[0-9][0-9][0-9][0-9][0-9]__*__DQMIO.root" )
echo "ok"

# Extract pedestals
echo -n "Processing ped runs: "
if [ -f "${dataDir}/${outputFile}" ]; then
    rm "${dataDir}/${outputFile}"
fi
for run in "${runsList[@]}"; do
    # Do something with the runs
    runNumber="$(echo "${run}" | sed "s|${localRunsDir}/DQM_V0001_R000||g")"
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

# Return to initial directory
cd "${curDir}"
echo "All done!"
