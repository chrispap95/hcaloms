import argparse
import os
import re
import subprocess
from datetime import datetime

import numpy as np
import ROOT


#
# The following functions can convert bin numbers <-> ieta, iphi for the DQM and the mapping files
#
def ietaDQM(ix):
    ieta = ix - 43
    if ix >= 43:
        ieta = ix - 42
    return ieta


def iphiDQM(iy):
    return iy


def ixMap(ieta):
    return ieta + 33


def iyMap(iphi):
    return iphi


parser = argparse.ArgumentParser(
    description="This script is used to extract the mean and rms for pedestals"
)
parser.add_argument("-f", "--inputFile", help="Input file name", required=True)
parser.add_argument(
    "-t", "--timeStamp", help="Include run timestamp", action="store_true"
)
parser.add_argument(
    "-z",
    "--suppressZero",
    help="Suppress runs that give zero for all pedestals",
    action="store_true",
)
parser.add_argument("-d", "--debug", help="Turns debugging on", action="store_true")
args = parser.parse_args()

inputDir = "/data/hcaldqm/DQMIO/LOCAL/"
sep = "\t"

# Get environment variables
env = os.environ.copy()

# Load channel mapping
fileMap = ROOT.TFile.Open("data/channel_SiPM_size.root")

# Get Run Number from filename
runNum = args.inputFile[14:20]
fileIn = ROOT.TFile.Open(inputDir + args.inputFile)

outputStr = ""
outputStr += f"{runNum}{sep}"

# Get EventInfo
# infoDir = fileIn.Get(f'DQMData/Run {runNum}/Hcal/Run summary/EventInfo')
# infoKeys = infoDir.GetListOfKeys()
# for i in infoKeys:
#    if 'processStartTimeStamp' in i.GetName():
#        startTime = float(re.sub('[^0-9.]','',i.GetName()))
#        if args.timeStamp:
#            outputStr += f"{datetime.fromtimestamp(startTime)}{sep}"

sqlOut = subprocess.run(
    [
        "sqlplus64",
        "-S",
        f"{env['DB_CMS_RCMS_USR']}/{env['DB_CMS_RCMS_PWD']}@cms_rcms",
        "@/data/hcaldqm/HCALDQM-INSTALLATION/Utilities/WBM/sql_templates/query.sql",
        "STRING_VALUE",
        "CMS.HCAL_LEVEL_1:LOCAL_RUNKEY_SELECTED",
        runNum,
    ],
    capture_output=True,
)
sqlOut = sqlOut.stdout.decode("utf-8")
timeStamp = sqlOut.split("\n")[2]
timeStamp = timeStamp[: timeStamp.rfind(" ", 3)]
if args.timeStamp:
    outputStr += f"'{timeStamp} Europe/Zurich'{sep}"

# Lists for sensors
sensors = {
    3: {"mean": [], "rms": []},
    4: {"mean": [], "rms": []},
    5: {"mean": [], "rms": []},
    6: {"mean": [], "rms": []},
    "HF": {"mean": [], "rms": []},
    "HO": {"mean": [], "rms": []},
}

# Populate lists for HB, HE, HF
for depth in range(1, 8):
    # Load the plots
    plot_map = fileMap.Get(f"MyHcalAnlzr/hist2D_depth{depth}")
    plot_mean = fileIn.Get(
        f"DQMData/Run {runNum}/Hcal/Run summary/PedestalTask/Mean/depth/depth{depth}"
    )
    plot_rms = fileIn.Get(
        f"DQMData/Run {runNum}/Hcal/Run summary/PedestalTask/RMS/depth/depth{depth}"
    )
    # Unpack the channels for HB, HE
    # Bin limits for the DQM plots
    xi, xf, yi, yf = 14, 71, 1, 72
    for i in range(xi, xf + 1):
        for j in range(yi, yf + 1):
            if plot_mean.GetBinContent(i, j) != 0:
                ieta = ietaDQM(i)
                iphi = iphiDQM(j)
                xmap = ixMap(ieta)
                ymap = iyMap(iphi)
                sensorSize = int(plot_map.GetBinContent(xmap, ymap))
                if sensorSize != 0:
                    sensors[sensorSize]["mean"].append(plot_mean.GetBinContent(i, j))
                    sensors[sensorSize]["rms"].append(plot_rms.GetBinContent(i, j))
    # Unpack the channels for HF
    # Bin limits for the DQM plots
    xi, xf, yi, yf = 1, 13, 1, 72
    xPlusOffset = 71
    for i in range(xi, xf + 1):
        for j in range(yi, yf + 1):
            # HF Minus
            if plot_mean.GetBinContent(i, j) != 0:
                sensors["HF"]["mean"].append(plot_mean.GetBinContent(i, j))
                sensors["HF"]["rms"].append(plot_rms.GetBinContent(i, j))
            # HF Plus
            if plot_mean.GetBinContent(i + xPlusOffset, j) != 0:
                sensors["HF"]["mean"].append(
                    plot_mean.GetBinContent(i + xPlusOffset, j)
                )
                sensors["HF"]["rms"].append(plot_rms.GetBinContent(i + xPlusOffset, j))

# Fill HO pedestals
plot_mean = fileIn.Get(
    f"DQMData/Run {runNum}/Hcal/Run summary/PedestalTask/Mean/depth/depthHO"
)
plot_rms = fileIn.Get(
    f"DQMData/Run {runNum}/Hcal/Run summary/PedestalTask/RMS/depth/depthHO"
)
xi, xf, yi, yf = 14, 71, 1, 72
for i in range(xi, xf + 1):
    for j in range(yi, yf + 1):
        if plot_mean.GetBinContent(i, j) != 0:
            sensors["HO"]["mean"].append(plot_mean.GetBinContent(i, j))
            sensors["HO"]["rms"].append(plot_rms.GetBinContent(i, j))

# Calculate values per sensor type and print them out
areAllZero = True
for s in sensors.keys():
    arrayMean = np.array(sensors[s]["mean"])
    arrayRMS = np.array(sensors[s]["rms"])
    if args.debug:
        outputStr += f"{len(arrayMean)}{sep}"
    if len(arrayMean) == 0:
        outputStr += f"''{sep}''{sep}"
    else:
        if (arrayMean.mean() > 0.0) or (arrayRMS.mean() > 0.0):
            areAllZero = False
        outputStr += f"{arrayMean.mean()}{sep}{arrayRMS.mean()}{sep}"
if not args.suppressZero:
    print(outputStr)
elif not areAllZero:
    print(outputStr)
