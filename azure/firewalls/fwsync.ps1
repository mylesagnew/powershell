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
$sourceSubscriptionId = [System.Environment]::GetEnvironmentVariable("SOURCE_SUBSCRIPTION_ID")
$sourceResourceGroup = [System.Environment]::GetEnvironmentVariable("SOURCE_RESOURCE_GROUP")
$sourceFirewallPolicyName = [System.Environment]::GetEnvironmentVariable("SOURCE_FIREWALL_POLICY_NAME")
$targetSubscriptionId = [System.Environment]::GetEnvironmentVariable("TARGET_SUBSCRIPTION_ID")
$targetResourceGroup = [System.Environment]::GetEnvironmentVariable("TARGET_RESOURCE_GROUP")
$targetFirewallPolicyName = [System.Environment]::GetEnvironmentVariable("TARGET_FIREWALL_POLICY_NAME")
$exportPath = [System.Environment]::GetEnvironmentVariable("EXPORT_PATH")

# Connect to Azure and set context for source firewall
Connect-AzAccount
Set-AzContext -Subscription $sourceSubscriptionId

# Retrieve source firewall policy rule collection groups
$sourceColgroups = Get-AzFirewallPolicy -Name $sourceFirewallPolicyName -ResourceGroupName $sourceResourceGroup

# Connect to target subscription and set context
Set-AzContext -Subscription $targetSubscriptionId

# Retrieve target firewall policy rule collection groups
$targetColgroups = Get-AzFirewallPolicy -Name $targetFirewallPolicyName -ResourceGroupName $targetResourceGroup

# Function to synchronize rules
function Sync-Rules {
    param (
        $sourceRules,
        $targetPolicyName,
        $targetResourceGroup
    )
    foreach ($rule in $sourceRules) {
        $ruleExists = $false
        $targetRules = Get-AzFirewallPolicyRuleCollectionGroup -Name $rule.Name -ResourceGroupName $targetResourceGroup -AzureFirewallPolicyName $targetPolicyName

        if ($targetRules) {
            $ruleExists = $true
        }

        if (-not $ruleExists) {
            Write-Output "Creating rule $($rule.Name) in target firewall"
            New-AzFirewallPolicyRuleCollectionGroup -Name $rule.Name -ResourceGroupName $targetResourceGroup -AzureFirewallPolicyName $targetPolicyName -RuleCollection $rule.RuleCollection
        } else {
            Write-Output "Rule $($rule.Name) already exists in target firewall"
        }
    }
}

# Iterate over source rule collection groups and synchronize rules to target firewall
foreach ($colgroup in $sourceColgroups.RuleCollectionGroups) {
    $c = Out-String -InputObject $colgroup -Width 500
    $collist = $c -split "/"
    $colname = ($collist[-1]).Trim()

    $sourceRulecolgroup = Get-AzFirewallPolicyRuleCollectionGroup -Name $colname -ResourceGroupName $sourceResourceGroup -AzureFirewallPolicyName $sourceFirewallPolicyName
    $targetRulecolgroup = Get-AzFirewallPolicyRuleCollectionGroup -Name $colname -ResourceGroupName $targetResourceGroup -AzureFirewallPolicyName $targetFirewallPolicyName

    if ($sourceRulecolgroup.properties.RuleCollection.rules.RuleType -contains "NetworkRule") {
        Sync-Rules -sourceRules $sourceRulecolgroup.properties.RuleCollection.rules -targetPolicyName $targetFirewallPolicyName -targetResourceGroup $targetResourceGroup
    }
    if ($sourceRulecolgroup.properties.RuleCollection.rules.RuleType -contains "ApplicationRule") {
        Sync-Rules -sourceRules $sourceRulecolgroup.properties.RuleCollection.rules -targetPolicyName $targetFirewallPolicyName -targetResourceGroup $targetResourceGroup
    }
    if ($sourceRulecolgroup.properties.RuleCollection.rules.RuleType -contains "NatRule") {
        Sync-Rules -sourceRules $sourceRulecolgroup.properties.RuleCollection.rules -targetPolicyName $targetFirewallPolicyName -targetResourceGroup $targetResourceGroup
    }
}
