# Load .env file
$envFilePath = ".\.env"
$envFile = Get-Content $envFilePath -Raw
$envFile -split "`n" | ForEach-Object {
    if ($_ -match "^(.*?)=(.*?)$") {
        $name = $matches[1]
        $value = $matches[2]
        [System.Environment]::SetEnvironmentVariable($name, $value)
    }
}

# Extract environment variables
$subscriptionId = [System.Environment]::GetEnvironmentVariable("SUBSCRIPTION_ID")
$resourceGroup = [System.Environment]::GetEnvironmentVariable("RESOURCE_GROUP")
$firewallPolicyName = [System.Environment]::GetEnvironmentVariable("FIREWALL_POLICY_NAME")
$exportPath = [System.Environment]::GetEnvironmentVariable("EXPORT_PATH")

# Connect to Azure and set context
Connect-AzAccount
Set-AzContext -Subscription $subscriptionId

# Retrieve firewall policy rule collection groups
$colgroups = Get-AzFirewallPolicy -Name $firewallPolicyName -ResourceGroupName $resourceGroup

# Iterate over rule collection groups and export rules to CSV files
foreach ($colgroup in $colgroups.RuleCollectionGroups) {
    $c = Out-String -InputObject $colgroup -Width 500
    $collist = $c -split "/"
    $colname = ($collist[-1]).Trim()

    $rulecolgroup = Get-AzFirewallPolicyRuleCollectionGroup -Name $colname -ResourceGroupName $resourceGroup -AzureFirewallPolicyName $firewallPolicyName

    if ($rulecolgroup.properties.RuleCollection.rules.RuleType -contains "NetworkRule") {
        $rulecolgroup.properties.RuleCollection.rules | Select-Object Name, RuleType, @{n="SourceAddresses"; e={$_.SourceAddresses -join ","}}, @{n="protocols"; e={$_.protocols -join ","}}, @{n="DestinationAddresses"; e={$_.DestinationAddresses -join ","}}, @{n="SourceIpGroups"; e={$_.SourceIpGroups -join ","}}, @{n="DestinationIpGroups"; e={$_.DestinationIpGroups -join ","}}, @{n="DestinationPorts"; e={$_.DestinationPorts -join ","}}, @{n="DestinationFqdns"; e={$_.DestinationFqdns -join ","}} | Export-Csv -Path "$exportPath\NetworkRules.csv" -Append -NoTypeInformation -Force
    }
    if ($rulecolgroup.properties.RuleCollection.rules.RuleType -contains "ApplicationRule") {
        $rulecolgroup.properties.RuleCollection.rules | Select-Object Name, RuleType, TerminateTLS, @{n="SourceAddresses"; e={$_.SourceAddresses -join ","}}, @{n="TargetFqdns"; e={$_.TargetFqdns -join ","}}, @{n="Protocols"; e={$_.Protocols -join ","}}, @{n="SourceIpGroups"; e={$_.SourceIpGroups -join ","}}, @{n="WebCategories"; e={$_.WebCategories -join ","}}, @{n="TargetUrls"; e={$_.TargetUrls -join ","}} | Export-Csv -Path "$exportPath\ApplicationRules.csv" -Append -NoTypeInformation -Force
    }
    if ($rulecolgroup.properties.RuleCollection.rules.RuleType -contains "NatRule") {
        $rulecolgroup.properties.RuleCollection.rules | Select-Object Name, RuleType, TranslatedPort, TranslatedAddress, @{n="SourceAddresses"; e={$_.SourceAddresses -join ","}}, @{n="SourceIpGroups"; e={$_.SourceIpGroups -join ","}}, @{n="Protocols"; e={$_.Protocols -join ","}}, @{n="DestinationAddresses"; e={$_.DestinationAddresses -join ","}}, @{n="DestinationPorts"; e={$_.DestinationPorts -join ","}} | Export-Csv -Path "$exportPath\DnatRules.csv" -Append -NoTypeInformation -Force
    }
}
