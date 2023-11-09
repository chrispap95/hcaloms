#!/bin/bash
#
# wrapUpdates.sh:
#     This script is going to be run by cron to update all information periodically
#     Input:
#         - $1: CMSSW version
#         - $2: directory for logs

# Set the input variables
CMSSW_VERSION="$1"
LOG_DIR="$2"

# Get the directories of interest
SCRIPT_DIR="$(dirname "$0")"
cd "${SCRIPT_DIR}"
CURRENT_DIR=$(pwd)

# Set up local environment & configuration
# shellcheck source=/dev/null
source envSetup.sh

# Set up CMSSW
# shellcheck source=/dev/null
source /opt/offline/cmsset_default.sh
CMSSW_PATH="../../CMSSW/${CMSSW_VERSION}"
cd "${CMSSW_PATH}/src"
eval "$(scramv1 runtime -sh)"
cd "${CURRENT_DIR}"

# Set up logging
if [ ! -f "${LOG_DIR}" ]; then
    mkdir -pv "${LOG_DIR}"
fi
source logger.sh

# Run the updater scripts
# Any new periodic tasks should be appended here
source updatePedRuns.sh "${CURRENT_DIR}" "${LOG_DIR}/updatePedRuns.log"
source updateLocalRuns.sh "${CURRENT_DIR}" "${LOG_DIR}/updateLocalRuns.log"
