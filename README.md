# HCAL OMS page scripts

[![Code style: black](https://img.shields.io/badge/code%20style-black-000000.svg)](https://github.com/psf/black)

This repository contains scripts for uploading and updating information on OMS regarding HCAL.

## Some general information

For each widget/page the following scripts & files need to be created:

- `uploadAll<something>.sh` script that will upload all existing information to the DB. This can be run at first time or everytime the DB needs to be recreated.
- `update<something>.sh` script that will be run with `cron` every x minute(s). This is necessary in order to automate the update process and make our pages dynamic.
- `DBUtils/<something>.ctl` file that contains the SQL query that populates the DB.
- `DBUtils/<something>.par` file that contains parameters needed to run the SQL data loader.
