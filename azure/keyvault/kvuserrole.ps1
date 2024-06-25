# Function to read the .env file and return a dictionary of key-value pairs
function Get-EnvVars {
    $envFilePath = ".\.env"
    $envVars = @{}
    
    if (Test-Path $envFilePath) {
        $lines = Get-Content $envFilePath
        
        foreach ($line in $lines) {
            $line = $line.Trim()
            
            if ($line -and $line -notmatch '^\s*#' -and $line -match '=' ) {
                $parts = $line -split '=', 2
                $key = $parts[0].Trim()
                $value = $parts[1].Trim()
                $envVars[$key] = $value
            }
        }
    } else {
        Write-Error "The .env file was not found in the current directory."
        exit
    }
    
    return $envVars
}

# Load the environment variables
$envVars = Get-EnvVars

# Extract variables from the dictionary
$entraGroupName = $envVars['ENTRA_GROUP_NAME']
$azureRegion = $envVars['AZURE_REGION']
$CXX = $envVars['CXX']

# Log in to Azure if not already authenticated
Connect-AzAccount

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
    # Get the user's first and last names and display name
    $userObject = Get-AzADUser -ObjectId $member.Id
    $firstNameInitial = $userObject.GivenName.Substring(0, 1).ToUpper()
    $lastNameInitial = $userObject.Surname.Substring(0, 1).ToUpper()
    $displayName = $userObject.DisplayName -replace '\s', ''  # Remove spaces from DisplayName

    if ($firstNameInitial -eq $null -or $lastNameInitial -eq $null -or $displayName -eq $null) {
        Write-Warning "Skipping a member with missing or invalid data."
        continue
    }

    # Define the Key Vault name with the desired convention
    $keyVaultName = "$CXX-$firstNameInitial$lastNameInitial-KV1"
    $resourceGroupName = "C00-$firstNameInitial$lastNameInitial-$displayName-rg"

    # Assign the 'Key Vault Secrets User' role to the user for the Key Vault
    Write-Output "Assigning 'Key Vault Secrets User' role to '$userObject.UserPrincipalName' for Key Vault '$keyVaultName'..."
    New-AzRoleAssignment -ObjectId $member.Id -RoleDefinitionName "Key Vault Secrets User" -Scope "/subscriptions/$((Get-AzContext).Subscription.Id)/resourceGroups/$resourceGroupName/providers/Microsoft.KeyVault/vaults/$keyVaultName"

    Write-Output "Role 'Key Vault Secrets User' assigned successfully to '$userObject.UserPrincipalName' for Key Vault '$keyVaultName'."
}

Write-Output "Script execution completed."
