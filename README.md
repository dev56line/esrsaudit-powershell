### README file for Repository
ESRS Login automation with TeraTerm Macro and etc...

### Version Info
PowerShell:  
  PSVersion : 5.1.14393.1944  

TeraTerm : 4.97 (SVN# 6995)  
ESRS-VE : 3.22.00.06  

DataDomain : 6.0.1.30

### Files
##### Directory: C:\<path_to_workingdir>
  - Overview
    - README.md
  - Programs (PowerShell Scripts)
    - KickerScript.ps1
    - MainScript.ps1
  - Programs (TeraTerm Macro)
    - main_TTLMacro.ttl
  - Configuration Files
    - main_config.ini
    - main_ttlconfig.ini
  - Password Files(if not exist, create with Teraterm pop-ups)
    - ESRS_Gateway1.dat
    - ESRS_Gateway2.dat
  - Batch files
    - StopMacro_for_Gateway1.bat
    - RestartMacro_for_Gateway1.bat
    - StopMacro_for_Gateway2.bat
    - RestartMacro_for_Gateway2.bat

##### Directory: C:\<path_to_workingdir>\DataDomainOps
  - Programs (TeraTerm Macro)
    - Failback_ESRS_Gateway.ttl
    - Failover_ESRS_Gateway.ttl
  - Configuration Files
    - TTL_Config_for_manual_ESRS_Change.ini
  - Password Files(if not exist, create with Teraterm pop-ups)
    - DD_credentials.dat

##### Directory: C:\<path_to_workingdir>\ManualServiceCheck
  - Programs (TeraTerm Macro)
    - ManualServiceCheck_Gateway1.ttl
    - ManualServiceCheck_Gateway2.ttl
  - Configuration Files
    - TTLconfig_for_ManualServiceCheck.ini
  - Password Files(if not exist, create with Teraterm pop-ups)
    - ESRS_Gateway1_password.dat
    - ESRS_Gateway2_password.dat
