# Initial Scripted by H.Wakabayashi
# Description :
#   - Load parameters from config.ini
#   - Automote ssh connection to ESRS-VE Server
#   - Check ESRS connectivity/service status
# Pre-requirements :
#   - Enabled Execution-Policy on PowerShell
#   - Executable TeraTerm macro from the server on which this script runs
#   - Disabled auto-logging function on TeraTerm
#   - Enabled auto-window closing on TeraTerm

# ////// ========= Pre-Settings =========
# Read parameters from configuration file
$lines = Get-Content .\main_config.ini
foreach ($line in $lines) {
    if($line -match "^$"){ continue }
    if($line -match "^\s*;"){ continue }

    $key, $value = $line.split('=', 2)
    Invoke-Expression "`$$key='$value'"
}

# Set Service Names in Array
[string[]]$EsrsServices = @(`
    "esrsalarm", `
    "esrsauditlogging", `
    "esrsauth", `
    "esrsusermanagement", `
    "esrsconfigtool", `
    "esrsconnectivityreport", `
    "esrsdataitems", `
    "esrsdevicemanagement", `
    "esrsjcemc", `
    "esrskeepalive", `
    "esrsmftauth", `
    "esrsupdate", `
    "esrsremotescripts", `
    "esrsrsc", `
    "esrsvesp", `
    "esrsclient", `
    "esrshttpd", `
    "esrshttpdR", `
    "esrsconnectemc", `
    "esrsclientproxy", `
    "esrswatchdog", `
    "esrshttpdftp", `
    "esrshttpdlistener", `
    "postfix", `
    "shibd", `
    "apache2")

# Create Event source if not exist
if ((Get-ChildItem -Path HKLM:SYSTEM\CurrentControlSet\Services\EventLog\Application | `
    Select-String $EVENTSRCNAME) -eq $null) {
    New-EventLog -LogName Application -Source $EVENTSRCNAME
    Write-Output "Event Source $EVENTSRCNAME not found, Created."
}else{
    Write-Output "Event Source $EVENTSRCNAME has already exist."
}


# ////// ========= Functions
# Check flag existency
function CheckFlagExist($vehost) {

    if ($vehost -eq $HOSTNAME1){
        $flag = $FLAG1
    }elseif ($vehost -eq $HOSTNAME2){
        $flag = $FLAG2
    }else{
        Write-host "Wrong flag file for the host."
    }

    if ((Test-Path -Path $flag) -eq $false) {
        return $false
    }else{
        return $true
    }
}


# KickTtlMacro Function
function KickTtlMacro($vehost) {

    # case if ESRS Gateway1
    if ($vehost -eq $HOSTNAME1){
        $PASSWD = $PASSWD_FILE1
        $REMOTE_PROMPT = $REMOTE_PROMPT1
        $LOGFILE = $LOGFILE1
    # case if ESRS Gateway2
    }elseif ($vehost -eq $HOSTNAME2){
        $PASSWD = $PASSWD_FILE2
        $REMOTE_PROMPT = $REMOTE_PROMPT2
        $LOGFILE = $LOGFILE2
    }else{
        Write-Output "PowerShell Main Script seemed to get wrong hostname."
    }

    # Set Command arguments
    $TTLARGS = $MACRONAME + " " `
               + $vehost + " " `
               + $ESRSVEUSER + " " `
               + $VESVCUSER + " " `
               + $REMOTE_PROMPT + " " `
               + $WORKDIR + " " `
               + $LOGFILE + " " `
               + $PASSWD + " " `
               + $INI_FILE

    # Execute TeraTerm Macro
    echo "$vehost : [Macro Start, Connecting to $vehost ...]"
    Start-Process $TTPMACRO -ArgumentList $TTLARGS -Wait
}

# Check Connectivity Status from Logfiles
function ConnectionCheck ($vehost){

    if ($vehost -eq $HOSTNAME1){
        $logname = $LOGFILE1
    }elseif ($vehost -eq $HOSTNAME2){
        $logname = $LOGFILE2
    }else{
        Write-Output "Wrong hostname."
    }

    $str_con = Select-String -Pattern "Connectivity Status | Data not available" -Path $logname |ForEach-Object { $_.Line }

    if ($str_con.Contains("Connected") -eq $true) {
        $cstatus = ($str_con -split ":   ", 3).GetValue(1)
        return $cstatus
    } else {
        $cstatus = "Disconnected"
        return $cstatus
    }
}

# Check Each Service Status from Logfiles
function ServiceCheck($vehost) {
    if ($vehost -eq $HOSTNAME1){
        $logname = $LOGFILE1
    }elseif ($vehost -eq $HOSTNAME2){
        $logname = $LOGFILE2
    }else{
        Write-Output "Wrong hostname."
    }

    $array = $EsrsServices
    $serviceName = New-Object 'String[]' (26)
    $serviceStatus = New-Object 'String[]' (26)
    for ($i=0 ; $i -lt $array.Length; $i++) {

            $str_svc = Select-String -Pattern $array[$i] -Path $logname |ForEach-Object { $_.Line }
            $serviceName[$i] = ($str_svc -replace "^\[*.*\]\s","" `
                            -replace "  * "," | " `
                            -split " | ", 5).GetValue(0)
            $serviceStatus[$i] = ($str_svc -replace "^\[*.*\]\s","" `
                            -replace "  * "," | " `
                            -split " | ", 5).GetValue(2)

            ## Writing Event if error
            if ($serviceStatus[$i] -ne "Running") {
                Write-host $serviceName[$i]" ::: ERROR"
            }else{
                Write-host $serviceName[$i]" ::: OK"
            }
    }

    if ($serviceStatus.Contains("Not") -eq $true){
        return $false
    } else {
        return $true
    }
}

function WriteEventLog($status){

    if ($status -ne "Connected") {
    # case status changed from Connected to DisConnected
        $msg1 = "ESRS Gateway has not been currently connected to EMC GAS Server. Please contact EMC Support Team."
        Write-EventLog -LogName Application -Source $EVENTSRCNAME -EntryType Error -EventId 1 -Message $msg1

    }else{
    # case status changed from Disconnected to Connected(Recovered)
        $msg5 = "ESRS Gateway Connectivity has been recovered from Disconnected to Connected."
        Write-Host $msg5
    }
}

function CheckTimeStamp($filename){
    $ts = (Get-ItemProperty $filename).LastWriteTime
    return $ts
}


# ++++++++++++++++++++++++++++ Main-Task ++++++++++++++++++++++++++++

# Initialize to Compare
$ConnectivityStatus1 = ""
$ServiceStatus1 = @{}
$ConnectivityStatus2 = ""
$ServiceStatus2 = @{}
$ts1 = $null
$ts2 = $null
$retry1 = $false
$retry2 = $false

# Start Closed Loop
while ($true) {
    echo "------------------------------------------------------------"
    echo ""
    Start-Transcript -Path $PSLOGFILE
    echo ""


# ////// ========= Runner Start =========
    ## Operations
    echo "$HOSTNAME1 : [ === Starting Operations === ]"

    if ((CheckFlagExist $HOSTNAME1) -eq $true) {
        echo "$HOSTNAME1 : [Flag file already exist, Nothing to do.]"
        $ConnectivityStatus1 = ""
        $ServiceStatus1 = @{}
        Start-Sleep -Seconds 5
    }else{
        echo "$HOSTNAME1 : [No flag files, Kick start macro.]"
        KickTtlMacro $HOSTNAME1

        ## Check timestamp of logfiles
        $ts1tmp = CheckTimeStamp $LOGFILE1

        ## If Log file does not exist, do retry up to 3 times.
        if ($ts1tmp -eq $ts1) {
            ## Set Error-Counter
            [int]$rcount = 2;

            ## Retry if counter is not 0
            while ($rcount -ne 0) {
                echo "$HOSTNAME1 : [Attempting $rcount try.]"
                Start-Sleep -Seconds 5
                KickTtlMacro $HOSTNAME1
                ## Check timestamp of logfiles
                $ts1tmp = CheckTimeStamp $LOGFILE1
                # decrease retry count
                $rcount--

                # if create logfile on retry, execute operation and exit the loop
                if ($ts1tmp -ne $ts1) {
                    echo "$HOSTNAME1 : [ === Checking ESRS-VE Connectivity Status === ]"
                    $tmpConStatus1 = (ConnectionCheck $HOSTNAME1)
                        Write-Output "ESRS Gateway Status : $tmpConStatus1"

                    ## Compare status with past loop result
                    if ($ConnectivityStatus1 -eq "") {
                        echo ""
                    }elseif ($tmpConStatus1 -ne $ConnectivityStatus1) {
                        Write-host "Connection Status was changed."
                        $condiff = (Compare-Object $tmpConStatus1 $ConnectivityStatus1)

                        if (($condiff | Where-Object {$_.InputObject -eq "Connected"}).SideIndicator -eq "=>"){
                            # case status changed from Connected to DisConnected
                            Write-host "Connectivity Status on $HOSTNAME1 was changed from Connected to Disconnected."
                            $msg10 = "ESRS Gateway $HOSTNAME1 has not been currently connected to EMC GAS Server. Please contact EMC Support Team."
                            Write-EventLog -LogName Application -Source $EVENTSRCNAME -EntryType Error -EventId 10 -Message $msg10
                        }else{
                            # case status changed from Disconnected to Connected(Recovered)
                            Write-Host "Connectivity Status on $HOSTNAME1 was changed from Disconnected to Connected."
                            $msg11 = "ESRS Gateway $HOSTNAME1 Connectivity was recovered."
                            Write-EventLog -LogName Application -Source $EVENTSRCNAME -EntryType Information -EventId 11 -Message $msg11
                        }

                    }else{
                        Write-host "Connection Status was not changed"
                    }

                    # Store Status and reset temporary value
                    $ConnectivityStatus1 = $tmpConStatus1
                    $tmpConStatus1 = ""


                    echo "$HOSTNAME1 : [ === Checking ESRS-VE Service Status === ]"
                    $tmpSvcStatus1 = (ServiceCheck $HOSTNAME1)

                    ## Compare status with past loop result
                    if ($ServiceStatus1.Count -eq 0) {
                        echo ""
                    }else{
                        $svcdiff = (Compare-Object $tmpSvcStatus1 $ServiceStatus1)
                        if ($svcdiff -ne $null){
                            Write-Host "Service status was changed."
                            if (($svcdiff | Where-Object {$_.InputObject -eq "False"}).SideIndicator -eq "<="){
                                Write-host "Service was recovered. All Service in $HOSTNAME1 is running."
                                $msg21 = "All services on $HOSTNAME1 recovered."
                                Write-EventLog -LogName Application -Source $EVENTSRCNAME -EntryType Information -EventId 21 -Message $msg21
                            }else{
                                Write-Host "Service dead."
                                $msg20 = "Some services on $HOSTNAME1 dead. Please check logfiles."
                                Write-EventLog -LogName Application -Source $EVENTSRCNAME -EntryType Error -EventId 20 -Message $msg20
                                }
                        }else{
                            Write-Host "Service status was not changed."
                        }
                    }

                    # Store Status and reset temporary value
                    $ServiceStatus1 = $tmpSvcStatus1
                    $tmpSvcStatus1 = @{}

                    # Store TimeStamp and reset current timestamp
                    $ts1 = $ts1tmp
                    $ts1tmp = $null

                    # exit loop
                    break
                 }
            }


            if ($rcount -eq 0) {
                echo "$HOSTNAME1 : [MainScript seemed to be failed to kick macro.]"
                $msg30 = "PowerShell retried Three times on $HOSTNAME1. But seemed to be fail to establish connection. Aborted."

                if ($retry1 -eq $false) {
                    echo "$HOSTNAME1 : [Failure of retry is recorded to Eventlog.]"
                    Write-EventLog -LogName Application -Source $EVENTSRCNAME -EntryType Warning -EventId 30 -message $msg30
                    $retry1 = $true
                } else {
                    echo "$HOSTNAME1 : [Failure of retry is not written to EventLog.]"
                }
            }

        }else{
            ## ======= Normal Operation
                echo "$HOSTNAME1 : [ === Checking ESRS-VE Connectivity Status === ]"
                $tmpConStatus1 = (ConnectionCheck $HOSTNAME1)
                    Write-Output "ESRS Gateway Status : $tmpConStatus1"

                ## Compare status with past loop result
                if ($ConnectivityStatus1 -eq "") {
                    echo ""
                }elseif ($tmpConStatus1 -ne $ConnectivityStatus1) {
                    Write-host "Connection Status was changed."
                    $condiff = (Compare-Object $tmpConStatus1 $ConnectivityStatus1)

                    if (($condiff | Where-Object {$_.InputObject -eq "Connected"}).SideIndicator -eq "=>"){
                        # case status changed from Connected to DisConnected
                        Write-host "Connectivity Status on $HOSTNAME1 was changed from Connected to Disconnected."
                        $msg10 = "ESRS Gateway $HOSTNAME1 has not been currently connected to EMC GAS Server. Please contact EMC Support Team."
                        Write-EventLog -LogName Application -Source $EVENTSRCNAME -EntryType Error -EventId 10 -Message $msg10
                    }else{
                        # case status changed from Disconnected to Connected(Recovered)
                        Write-Host "Connectivity Status on $HOSTNAME1 was changed from Disconnected to Connected."
                        $msg11 = "ESRS Gateway $HOSTNAME1 Connectivity was recovered."
                        Write-EventLog -LogName Application -Source $EVENTSRCNAME -EntryType Information -EventId 11 -Message $msg11
                    }

                }else{
                    Write-host "Connection Status was not changed"
                }

                # Store Status and reset temporary value
                $ConnectivityStatus1 = $tmpConStatus1
                $tmpConStatus1 = ""


            echo "$HOSTNAME1 : [ === Checking ESRS-VE Service Status === ]"
            $tmpSvcStatus1 = (ServiceCheck $HOSTNAME1)

            ## Compare status with past loop result
            if ($ServiceStatus1.Count -eq 0) {
                echo ""
            }else{
                $svcdiff = (Compare-Object $tmpSvcStatus1 $ServiceStatus1)
                if ($svcdiff -ne $null){
                    Write-Host "Service status was changed."
                    if (($svcdiff | Where-Object {$_.InputObject -eq "False"}).SideIndicator -eq "<="){
                        Write-host "Service was recovered. All Service in $HOSTNAME1 is running."
                        $msg21 = "All services on $HOSTNAME1 recovered."
                        Write-EventLog -LogName Application -Source $EVENTSRCNAME -EntryType Information -EventId 21 -Message $msg21
                    }else{
                        Write-Host "Service dead."
                        $msg20 = "Some services on $HOSTNAME1 dead. Please check logfiles."
                        Write-EventLog -LogName Application -Source $EVENTSRCNAME -EntryType Error -EventId 20 -Message $msg20
                        }
                }else{
                    Write-Host "Service status was not changed."
                }
            }

            # Store Status and reset temporary value
            $ServiceStatus1 = $tmpSvcStatus1
            $tmpSvcStatus1 = @{}

            # Store TimeStamp and reset current timestamp
            $ts1 = $ts1tmp
            $ts1tmp = $null

        }
    }

# ////// ========= Runner End =========

# ------------------------------------------------------------------

# ////// ========= Runner Start =========
    ## Operations
    echo "$HOSTNAME2 : [ === Starting Operations === ]"

    if ((CheckFlagExist $HOSTNAME2) -eq $true) {
        echo "$HOSTNAME2 : [Flag file already exist, Nothing to do.]"
        $ConnectivityStatus2 = ""
        $ServiceStatus2 = @{}
        Start-Sleep -Seconds 5
    }else{
        echo "$HOSTNAME2 : [No flag files, Kick start macro.]"
        KickTtlMacro $HOSTNAME2

        ## Check timestamp of logfiles
        $ts2tmp = CheckTimeStamp $LOGFILE2

        ## If Log file does not exist, do retry up to 3 times.
        if ($ts2tmp -eq $ts2) {
            ## Set Error-Counter
            [int]$rcount = 2;

            ## Retry if counter is not 0
            while ($rcount -ne 0) {
                echo "$HOSTNAME2 : [Attempting $rcount try.]"
                Start-Sleep -Seconds 5
                KickTtlMacro $HOSTNAME2
                ## Check timestamp of logfiles
                $ts2tmp = CheckTimeStamp $LOGFILE2
                # decrease retry count
                $rcount--

                # if create logfile on retry, execute operation and exit the loop
                if ($ts2tmp -ne $ts2) {
                    echo "$HOSTNAME2 : [ === Checking ESRS-VE Connectivity Status === ]"
                    $tmpConStatus2 = (ConnectionCheck $HOSTNAME2)
                        Write-Output "ESRS Gateway Status : $tmpConStatus2"

                    ## Compare status with past loop result
                    if ($ConnectivityStatus2 -eq "") {
                        echo ""
                    }elseif ($tmpConStatus2 -ne $ConnectivityStatus2) {
                        Write-host "Connection Status was changed."
                        $condiff = (Compare-Object $tmpConStatus2 $ConnectivityStatus2)

                        if (($condiff | Where-Object {$_.InputObject -eq "Connected"}).SideIndicator -eq "=>"){
                            # case status changed from Connected to DisConnected
                            Write-host "Connectivity Status on $HOSTNAME2 was changed from Connected to Disconnected."
                            $msg10 = "ESRS Gateway $HOSTNAME2 has not been currently connected to EMC GAS Server. Please contact EMC Support Team."
                            Write-EventLog -LogName Application -Source $EVENTSRCNAME -EntryType Error -EventId 10 -Message $msg10
                        }else{
                            # case status changed from Disconnected to Connected(Recovered)
                            Write-Host "Connectivity Status on $HOSTNAME2 was changed from Disconnected to Connected."
                            $msg11 = "ESRS Gateway $HOSTNAME2 Connectivity was recovered."
                            Write-EventLog -LogName Application -Source $EVENTSRCNAME -EntryType Information -EventId 11 -Message $msg11
                        }

                    }else{
                        Write-host "Connection Status was not changed"
                    }

                    # Store Status and reset temporary value
                    $ConnectivityStatus2 = $tmpConStatus2
                    $tmpConStatus2 = ""


                    echo "$HOSTNAME2 : [ === Checking ESRS-VE Service Status === ]"
                    $tmpSvcStatus2 = (ServiceCheck $HOSTNAME2)

                    ## Compare status with past loop result
                    if ($ServiceStatus2.Count -eq 0) {
                        echo ""
                    }else{
                        $svcdiff = (Compare-Object $tmpSvcStatus2 $ServiceStatus2)
                        if ($svcdiff -ne $null){
                            Write-Host "Service status was changed."
                            if (($svcdiff | Where-Object {$_.InputObject -eq "False"}).SideIndicator -eq "<="){
                                Write-host "Service was recovered. All Service in $HOSTNAME2 is running."
                                $msg21 = "All services on $HOSTNAME2 recovered."
                                Write-EventLog -LogName Application -Source $EVENTSRCNAME -EntryType Information -EventId 21 -Message $msg21
                            }else{
                                Write-Host "Service dead."
                                $msg20 = "Some services on $HOSTNAME2 dead. Please check logfiles."
                                Write-EventLog -LogName Application -Source $EVENTSRCNAME -EntryType Error -EventId 20 -Message $msg20
                                }
                        }else{
                            Write-Host "Service status was not changed."
                        }
                    }

                    # Store Status and reset temporary value
                    $ServiceStatus2 = $tmpSvcStatus2
                    $tmpSvcStatus2 = @{}

                    # Store TimeStamp and reset current timestamp
                    $ts2 = $ts2tmp
                    $ts2tmp = $null

                    # exit loop
                    break
                 }
            }


            if ($rcount -eq 0) {
                echo "$HOSTNAME2 : [MainScript seemed to be failed to kick macro.]"
                $msg30 = "PowerShell retried Three times on $HOSTNAME2. But seemed to be fail to establish connection. Aborted."

                if ($retry2 -eq $false) {
                    echo "$HOSTNAME2 : [Failure of retry is recorded to Eventlog.]"
                    Write-EventLog -LogName Application -Source $EVENTSRCNAME -EntryType Warning -EventId 30 -message $msg30
                    $retry2 = $true
                } else {
                    echo "$HOSTNAME2 : [Failure of retry is not written to EventLog.]"
                }
            }

        }else{
            ## ======= Normal Operation
                echo "$HOSTNAME2 : [ === Checking ESRS-VE Connectivity Status === ]"
                $tmpConStatus2 = (ConnectionCheck $HOSTNAME2)
                    Write-Output "ESRS Gateway Status : $tmpConStatus2"

                ## Compare status with past loop result
                if ($ConnectivityStatus2 -eq "") {
                    echo ""
                }elseif ($tmpConStatus2 -ne $ConnectivityStatus2) {
                    Write-host "Connection Status was changed."
                    $condiff = (Compare-Object $tmpConStatus2 $ConnectivityStatus2)

                    if (($condiff | Where-Object {$_.InputObject -eq "Connected"}).SideIndicator -eq "=>"){
                        # case status changed from Connected to DisConnected
                        Write-host "Connectivity Status on $HOSTNAME2 was changed from Connected to Disconnected."
                        $msg10 = "ESRS Gateway $HOSTNAME2 has not been currently connected to EMC GAS Server. Please contact EMC Support Team."
                        Write-EventLog -LogName Application -Source $EVENTSRCNAME -EntryType Error -EventId 10 -Message $msg10
                    }else{
                        # case status changed from Disconnected to Connected(Recovered)
                        Write-Host "Connectivity Status on $HOSTNAME2 was changed from Disconnected to Connected."
                        $msg11 = "ESRS Gateway $HOSTNAME2 Connectivity was recovered."
                        Write-EventLog -LogName Application -Source $EVENTSRCNAME -EntryType Information -EventId 11 -Message $msg11
                    }

                }else{
                    Write-host "Connection Status was not changed"
                }

                # Store Status and reset temporary value
                $ConnectivityStatus2 = $tmpConStatus2
                $tmpConStatus2 = ""


            echo "$HOSTNAME2 : [ === Checking ESRS-VE Service Status === ]"
            $tmpSvcStatus2 = (ServiceCheck $HOSTNAME2)

            ## Compare status with past loop result
            if ($ServiceStatus2.Count -eq 0) {
                echo ""
            }else{
                $svcdiff = (Compare-Object $tmpSvcStatus2 $ServiceStatus2)
                if ($svcdiff -ne $null){
                    Write-Host "Service status was changed."
                    if (($svcdiff | Where-Object {$_.InputObject -eq "False"}).SideIndicator -eq "<="){
                        Write-host "Service was recovered. All Service in $HOSTNAME2 is running."
                        $msg21 = "All services on $HOSTNAME2 recovered."
                        Write-EventLog -LogName Application -Source $EVENTSRCNAME -EntryType Information -EventId 21 -Message $msg21
                    }else{
                        Write-Host "Service dead."
                        $msg20 = "Some services on $HOSTNAME2 dead. Please check logfiles."
                        Write-EventLog -LogName Application -Source $EVENTSRCNAME -EntryType Error -EventId 20 -Message $msg20
                        }
                }else{
                    Write-Host "Service status was not changed."
                }
            }

            # Store Status and reset temporary value
            $ServiceStatus2 = $tmpSvcStatus2
            $tmpSvcStatus2 = @{}

            # Store TimeStamp and reset current timestamp
            $ts2 = $ts2tmp
            $ts2tmp = $null

        }
    }

# ////// ========= Runner End =========


    #////// ========== End PowerShell Logging
    echo ""
    Stop-Transcript
    echo ""
    echo ""

    #////// ========== Wait for next loop
    Start-Sleep -Seconds $LOOP_INTERVAL

} ## == Closed Loop END.
