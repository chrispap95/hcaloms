SET UND OFF;
SET HEAD OFF;
SET LIN 5000;
SET PAGES 0;
SET VERIFY OFF;
set feedback off;
SELECT &1 FROM RUNSESSION_PARAMETER WHERE ( RUNSESSION_PARAMETER.NAME LIKE '&2' OR RUNSESSION_PARAMETER.NAME LIKE 'CMS.HCAL_LEVEL_1:RUN_HAS_STOPPED' OR RUNSESSION_PARAMETER.NAME LIKE 'CMS.HCAL_LEVEL_1:RUN_START_TIME') AND RUNSESSION_PARAMETER.RUNNUMBER=&3;
EXIT;
