# Log in to Azure if not already authenticated
Connect-AzAccount

# Define the Entra group name
$entraGroupName = "ENTRA NAME"

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

    # Create the unique resource group name format
    $resourceGroupName = "$($userPrincipalName.Replace('@', '-').Replace('.', '-'))-rg"

    # Check if the resource group exists
    $resourceGroup = Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue

    if ($resourceGroup -ne $null) {
        Write-Output "Deleting resource group '$resourceGroupName'..."
        
        # Remove role assignment before deleting the resource group
        $roleAssignments = Get-AzRoleAssignment -Scope "/subscriptions/$((Get-AzContext).Subscription.Id)/resourceGroups/$resourceGroupName" -ErrorAction SilentlyContinue
        foreach ($roleAssignment in $roleAssignments) {
            if ($roleAssignment.RoleDefinitionName -eq "Key Vault Secrets Officer" -and $roleAssignment.PrincipalId -eq $member.Id) {
                Write-Output "Removing 'Key Vault Secrets Officer' role assignment for user '$userPrincipalName' from resource group '$resourceGroupName'..."
                Remove-AzRoleAssignment -ObjectId $member.Id -RoleDefinitionName "Key Vault Secrets Officer" -Scope $roleAssignment.Scope -ErrorAction SilentlyContinue
            }
        }
        
        # Delete the resource group
        Remove-AzResourceGroup -Name $resourceGroupName -Force -ErrorAction SilentlyContinue
        
        Write-Output "Resource group '$resourceGroupName' deleted successfully."
    }
    else {
        Write-Warning "Resource group '$resourceGroupName' does not exist or has already been deleted."
    }
}

Write-Output "Script execution completed."
