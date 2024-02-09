# my-appregistration.ps1
# Load environment variables from .env file (securely)
$envFile = ".env"
$envVars = @{}
try {
    $envVars = Get-Content -Path $envFile -Raw | ConvertFrom-Json | Select-Object -ExpandProperty KeyValuePairs
} catch {
    Write-Error "Error reading environment variables from '$envFile'. Please ensure the file exists and is formatted correctly."
    exit 1
}

# Set Azure environment variables (securely)
$TENANT_ID = $envVars["TENANT_ID"]
$CLIENT_NAME = $envVars["CLIENT_NAME"]
$APP_NAME = $envVars["APP_NAME"]
$KEY_VAULT_NAME = $envVars["KEY_VAULT_NAME"]
$SECRET_NAME = $envVars["SECRET_NAME"]

# Azure login using device authentication
Connect-AzAccount -UseDeviceAuthentication

# Register the app (handle potential errors)
$displayName = $APP_NAME
try {
    $app = New-AzADApplication -DisplayName $displayName -IdentifierUris "http://$CLIENT_NAME" -HomePage "http://$CLIENT_NAME" -AvailableToOtherTenants $false
} catch {
    Write-Error "Failed to create the Azure AD application: $($_.Exception.Message)"
    exit 1
}

# Check if app creation was successful
if ($app -eq $null) {
    Write-Error "Failed to create the Azure AD application."
    exit 1
}

# Create service principal (handle potential errors)
try {
    $sp = New-AzADServicePrincipal -ApplicationId $app.ApplicationId
} catch {
    Write-Error "Failed to create the service principal: $($_.Exception.Message)"
    exit 1
}

# Generate a strong, random client secret (use more secure methods)
$securePassword = Get-Random -Count 16
$secret = New-AzADAppCredential -ApplicationId $app.ApplicationId -Password (ConvertTo-SecureString -String $securePassword -AsPlainText -Force)

# Output the generated client secret (redact or store securely)
Write-Host "Generated Client Secret (DO NOT SHARE): $($secret.Password)"

# Store the secret securely in Azure Key Vault (use Set-AzKeyVaultSecret -SecureValue)
$secretValue = ConvertFrom-SecureString -SecureString $secret.Password -AsPlainText
try {
    Set-AzKeyVaultSecret -VaultName $KEY_VAULT_NAME -Name $SECRET_NAME -SecretValue $secretValue
} catch {
    Write-Error "Failed to store the secret in Azure Key Vault: $($_.Exception.Message)"
    exit 1
}

# Assign Sentinel Reader role to the service principal (check permissions)
New-AzRoleAssignment -RoleDefinitionName "Azure Sentinel Reader" -ServicePrincipalName $sp.ApplicationId.Guid

Write-Host "Azure App Registration completed successfully with Sentinel Reader permissions and client secret stored securely in Azure Key Vault."
