param (
    [string]$FirewallName,
    [string]$ResourceGroupName
)

# Check if both parameters are provided
if (-not $FirewallName -or -not $ResourceGroupName) {
    Write-Output "Usage: .\restarfw.ps1 <Firewall Name> <Firewall Resource Group>"
    exit
}

# Get the Azure Firewall resource
$firewall = Get-AzFirewall -ResourceGroupName $ResourceGroupName -Name $FirewallName

if ($firewall -ne $null) {
    Write-Output "Stopping Azure Firewall..."
    
    # Stop the Azure Firewall
    Stop-AzFirewall -ResourceGroupName $ResourceGroupName -Name $FirewallName
    
    Write-Output "Azure Firewall stopped. Waiting for 30 seconds before starting..."
    Start-Sleep -Seconds 30
    
    Write-Output "Starting Azure Firewall..."
    
    # Start the Azure Firewall
    Start-AzFirewall -ResourceGroupName $ResourceGroupName -Name $FirewallName
    
    Write-Output "Azure Firewall has been restarted successfully."
} else {
    Write-Output "Azure Firewall not found. Please check the resource group name and firewall name."
}
