# Ensures you do not inherit an AzContext in your runbook
Disable-AzContextAutosave -Scope Process

# Connect to Azure with system-assigned managed identity
$AzureContext = (Connect-AzAccount -Identity).context

# Set and store context
$AzureContext = Set-AzContext -SubscriptionName $AzureContext.Subscription -DefaultProfile $AzureContext   

#Get all AKS Clusters  that should be part of the Schedule:
$AksClusters = Get-AzResource -ResourceType "Microsoft.ContainerService/managedClusters" -TagName "Operational-Schedule" -TagValue "Yes"

foreach ($AksCluster in $AksClusters) {

    Write-Output "Processing AKS Cluster $($AksCluster.Name)..."

    ### Time Offset calculation

    #Get Current UTC Time (default time zone in all Azure regions)
    $UTCNow = [System.DateTime]::UtcNow

    #Get the Value of the "Operational-UTCOffset" Tag, that represents the offset from UTC
    $UTCOffset = $($AksCluster.Tags)."Operational-UTCOffset"

    #Get current time in the Adjusted Time Zone
    if ($UTCOffset) {
        $TimeZoneAdjusted = $UTCNow.AddHours($UTCOffset)
        Write-Output "Current time of AKS Cluster after adjusting the Time Zone is: $TimeZoneAdjusted"
    }
    else {
        $TimeZoneAdjusted = $UTCNow
    }

    #GMT
    $TimeZone = [TimeZoneInfo]::FindSystemTimeZoneById("GMT Standard Time")
    $TimeZoneAdjusted = [TimeZoneInfo]::ConvertTimeFromUtc($TimeZoneAdjusted, $TimeZone)

    ### Current Time associations

    $Day = $TimeZoneAdjusted.DayOfWeek

    If ($Day -like "S*") {
        $TodayIsWeekend = $true
        $TodayIsWeekday = $false

    }
    else {
        $TodayIsWeekend = $false
        $TodayIsWeekday = $true
    }

    
    ### Get Exclusions
    $Exclude = $false
    $Reason = ""
    $Exclusions = $($AksCluster.Tags)."Operational-Exclusions"

    $Exclusions = $Exclusions.Split(',')
    
    foreach ($Exclusion in $Exclusions) {

        #Check excluded actions:
        If ($Exclusion.ToLower() -eq "stop") { $AksClusterActionExcluded = "Stop" }
        If ($Exclusion.ToLower() -eq "start") { $AksClusterActionExcluded = "Start" }
        
        #Check excluded days and compare with current day
        If ($Exclusion.ToLower() -like "*day") {
            if ($Exclusion -eq $Day) { $Exclude = $true; $Reason = $Day }
        }

        #Check excluded weekdays and copare with Today
        If ($Exclusion.ToLower() -eq "weekdays") {
            if ($TodayIsWeekday) { $Exclude = $true; $Reason = "Weekday" }
        }

        #Check excluded weekends and compare with Today
        If ($Exclusion.ToLower() -eq "weekends") {
            if ($TodayIsWeekend) { $Exclude = $true; $Reason = "Weekend" }
        }

        If ($Exclusion -eq (Get-Date -UFormat "%b %d")) {
            $Exclude = $true; $Reason = "Date Excluded"
        }

    }

    if (!$Exclude) {

        #Get values from Tags and compare to the current time

        if ($TodayIsWeekday) {

            $ScheduledTime = $($AksCluster.Tags)."Operational-Weekdays"
        
        }
        elseif ($TodayIsWeekend) {

            $ScheduledTime = $($AksCluster.Tags)."Operational-Weekends"

        }

        if ($ScheduledTime) {
            
            $ScheduledTime = $ScheduledTime.Split("-")
            $ScheduledStart = $ScheduledTime[0]
            $ScheduledStop = $ScheduledTime[1]
            
            $ScheduledStartTime = Get-Date -Hour $ScheduledStart -Minute 0 -Second 0
            $ScheduledStopTime = Get-Date -Hour $ScheduledStop -Minute 0 -Second 0

            If (($TimeZoneAdjusted -gt $ScheduledStartTime) -and ($TimeZoneAdjusted -lt $ScheduledStopTime)) {
                #Current time is within the interval
                Write-Output "AKS Cluster should be running now"
                $AksClusterAction = "Start"
            
            }
            else {
                #Current time is outside of the operational interval
                Write-Output "AKS Cluster should be stopped now"
                $AksClusterAction = "Stop"

            }

            If ($AksClusterAction -notlike "$AksClusterActionExcluded") {
                #Make sure that action was not excluded

                #Get AksCluster PowerState
                $AksClusterState = (Get-AzResource -ResourceId $AksCluster.Id).Properties.PowerState

                if (($AksClusterAction -eq "Start") -and ($AksClusterState -notlike "*running*")) {

                    Write-Output "Starting $($AksCluster.Name)..."
                    Start-AzAksCluster -ResourceGroupName $AksCluster.ResourceGroupName -Name $AksCluster.Name

                }
                elseif (($AksClusterAction -eq "Stop") -and ($AksClusterState -notlike "*stopped*")) {
                    
                    Write-Output "Stopping $($AksCluster.Name)..."
                    Stop-AzAksCluster -ResourceGroupName $AksCluster.ResourceGroupName -Name $AksCluster.Name

                }
                else {

                    Write-Output "AKS Cluster $($AksCluster.Name) status is: $AksClusterState . No action will be performed ..."

                }

                
            }
            else {
                Write-Output "AKS Cluster $($AksCluster.Name) is Excluded from changes during this run because Operational-Exclusions Tag contains action $AksClusterAction."

            }

        }
        else {

            Write-Output "Error: Scheduled Running Time for AKS Cluster was not detected. No action will be performed..."
        }
        

    }
    else {

        Write-Output "AKS Cluster $($AksCluster.Name) is Excluded from changes during this run because Operational-Exclusions Tag contains exclusion $Reason."
    }

}

Write-Output "Runbook completed."
