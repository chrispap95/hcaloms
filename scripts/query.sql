SET UND OFF;
SET HEAD OFF;
SET LIN 5000;
SET PAGES 0;
SET VERIFY OFF;
set feedback off;
SELECT STRING_VALUE 
FROM RUNSESSION_PARAMETER 
WHERE ( 
	RUNSESSION_PARAMETER.NAME LIKE 'CMS.HCAL_LEVEL_1:LOCAL_RUNKEY_SELECTED' OR 
	RUNSESSION_PARAMETER.NAME LIKE 'CMS.HCAL_LEVEL_1:RUN_START_TIME'
) AND RUNSESSION_PARAMETER.RUNNUMBER=&1;
EXIT;
