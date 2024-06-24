# Log in to Azure if not already authenticated
Connect-AzAccount

# Define the Entra group name
$entraGroupName = "ENTRAGROUP NAME"

# Get the Entra group object
$entraGroup = Get-AzADGroup -DisplayName $entraGroupName

if ($entraGroup -eq $null) {
    Write-Error "Group '$entraGroupName' not found."
    exit
}

# Get all members of the Entra group
$groupMembers = Get-AzADGroupMember -ObjectId $entraGroup.Id

# Check if there are any members in the group
if ($groupMembers.Count -eq 0) {
    Write-Output "No members found in the group '$entraGroupName'."
    exit
}

# Iterate over each group member
foreach ($member in $groupMembers) {
    # Get the user principal name (username)
    $userPrincipalName = $member.UserPrincipalName
    
    if ($userPrincipalName -eq $null) {
        Write-Warning "Skipping a member without a User Principal Name."
        continue
    }

    # Create a unique resource group name
    $resourceGroupName = "$($userPrincipalName.Replace('@', '-').Replace('.', '-'))-rg"

    # Create a new resource group
    Write-Output "Creating resource group '$resourceGroupName' for user '$userPrincipalName'..."
    New-AzResourceGroup -Name $resourceGroupName -Location "East US"

    # Assign the 'Key Vault Secrets Officer' role to the user for the new resource group
    Write-Output "Assigning 'Key Vault Secrets Officer' role to '$userPrincipalName' for resource group '$resourceGroupName'..."
    New-AzRoleAssignment -ObjectId $member.Id -RoleDefinitionName "Key Vault Secrets Officer" -Scope "/subscriptions/$((Get-AzContext).Subscription.Id)/resourceGroups/$resourceGroupName"

    Write-Output "Resource group '$resourceGroupName' created and role assigned successfully for user '$userPrincipalName'."
}

Write-Output "Script execution completed."
