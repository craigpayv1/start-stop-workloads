# This is a utility script to add tags to VMs in the Resource Group specified.
# Use login.ps1 first

$VMs = @("vmcraigtest01") # Add more VM names if needed
$ResourceGroupName = "craig-pay-sandbox-rg"

foreach ($VMName in $VMs) {
    # Get the resource group of the VM using az CLI
    $RG = az vm show --name $VMName --resource-group $ResourceGroupName --query resourceGroup -o tsv

    # Set the tags (replaces existing tags)
    az resource update `
        --resource-type "Microsoft.Compute/virtualMachines" `
        --name $VMName `
        --resource-group $RG `
        --set tags.Operational-Schedule="Yes" `
               tags.Operational-Weekdays="8-18" `
               tags.Operational-Weekends="" `
               tags.Operational-UTCOffset="0" `
               tags.Operational-Exclusions="Weekends"
}
