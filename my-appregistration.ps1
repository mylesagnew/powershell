# my-appregistration.ps1

# Load environment variables from .env file
$envFile = ".env"
$envVars = Get-Content $envFile | ForEach-Object { $_ -split '=' }
$envVars = @{}
foreach ($line in Get-Content $envFile) {
    $parts = $line -split '=', 2
    if ($parts.Count -eq 2) {
        $envVars[$parts[0].Trim()] = $parts[1].Trim()
    }
}

# Set Azure environment variables
$TENANT_ID = $envVars["TENANT_ID"]
$CLIENT_NAME = $envVars["CLIENT_NAME"]
$APP_NAME = $envVars["APP_NAME"]
$KEY_VAULT_NAME = $envVars["KEY_VAULT_NAME"]
$SECRET_NAME = $envVars["SECRET_NAME"]

# Azure login using device authentication
Connect-AzAccount -UseDeviceAuthentication

# Register the app
$displayName = $APP_NAME
$app = New-AzADApplication -DisplayName $displayName -IdentifierUris "http://$CLIENT_NAME" -HomePage "http://$CLIENT_NAME" -AvailableToOtherTenants $false

# Check if app creation was successful
if ($app -eq $null) {
    Write-Error "Failed to create the Azure AD application."
    exit 1
}

# Create service principal
$sp = New-AzADServicePrincipal -ApplicationId $app.ApplicationId

# Generate a client secret
$secret = New-AzADAppCredential -ApplicationId $app.ApplicationId -Password (ConvertTo-SecureString -String "your-secret-password" -AsPlainText -Force)

# Output the generated client secret
Write-Host "Generated Client Secret: $($secret.Password)"

# Store the secret securely in Azure Key Vault
$secretValue = ConvertFrom-SecureString -SecureString $secret.Password -AsPlainText
Set-AzKeyVaultSecret -VaultName $KEY_VAULT_NAME -Name $SECRET_NAME -SecretValue $secretValue

# Assign Sentinel Reader role to the service principal
New-AzRoleAssignment -RoleDefinitionName "Azure Sentinel Reader" -ServicePrincipalName $sp.ApplicationId.Guid

Write-Host "Azure App Registration completed successfully with Sentinel Reader permissions and client secret stored securely in Azure Key Vault."
