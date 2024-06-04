# PowerShell script to Backup DNS records and Cloudflare Worker configurations
$CloudflareEndpoint = "https://api.cloudflare.com/client/v4/"

# Array to store domain names
$domainList = @()

# Function to check environment variables
function Check-Environment {
    $envFile = Get-Content -Path ".env" -ErrorAction SilentlyContinue
    if ($envFile) {
        $envFile | ForEach-Object {
            $key, $value = $_ -split '=', 2
            [System.Environment]::SetEnvironmentVariable($key, $value, [System.EnvironmentVariableTarget]::Process)
        }
        Write-Host "Using .env file"
    } else {
        Write-Host "No .env file found. Exiting"
        exit 1
    }
}

# Function to fetch domains from Cloudflare
function Get-Domains {
    param (
        [int]$page = 1
    )

    try {
        $headers = @{
            "X-Auth-Email" = $env:CLOUDFLARE_USER_EMAIL
            "X-Auth-Key"   = $env:CLOUDFLARE_API_KEY
            "Content-Type" = "application/json"
        }

        $uri = "{0}zones?page={1}" -f $CloudflareEndpoint, $page

        Write-Host "Request URI: $uri"
        Write-Host "Headers: $($headers | Out-String)"

        $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers
    }
    catch {
        Write-Host "Error fetching domains: $_"
        exit 1
    }

    if ($null -eq $response) {
        Write-Host "Error: No response received from the Cloudflare API. Exiting."
        exit 1
    }

    Write-Host "Response from Cloudflare API:"
    $response | Format-List

    if ($null -eq $response.result_info) {
        Write-Host "Error: 'result_info' property not found in the response. Exiting."
        exit 1
    }

    $count      = $response.result_info.count
    $totalPages = $response.result_info.total_pages
    $totalCount = $response.result_info.total_count

    Write-Host "Fetching batch of $count DNS records ..."
    Add-DomainsToList $response

    if ($page -lt $totalPages) {
        Get-Domains -page ($page + 1)
    } else {
        Write-Host "Fetched $totalCount domains."
    }
}

# Function to add domains to the list
function Add-DomainsToList {
    param (
        [object]$response
    )

    $result = $response.result | ForEach-Object { [PSCustomObject]@{ id = $_.id; name = $_.name } }

    $domainList += $result
}

# Function to export DNS records for a domain
function Export-DNS {
    param (
        [object]$domain
    )

    if (!(Test-Path "./domains")) {
        New-Item -ItemType Directory -Path "./domains"
    }

    $domainId   = $domain.id
    $domainName = $domain.name

    $response = Invoke-RestMethod -Uri ("{0}zones/{1}/dns_records/export" -f $CloudflareEndpoint, $domainId) -Method Get -Headers @{
        "X-Auth-Email" = $env:CLOUDFLARE_USER_EMAIL
        "X-Auth-Key"   = $env:CLOUDFLARE_API_KEY
        "Content-Type" = "application/json"
    }

    if ($?) {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $response | Out-File -FilePath "./domains/${domainName}_${timestamp}.txt"
        Write-Host "Exported DNS records for domain: $domainName"
    } else {
        Write-Host "Error exporting DNS records for domain $domainName. Exiting."
        exit 1
    }
}

# Function to export Cloudflare Worker configuration for a domain
function Export-Worker {
    param (
        [object]$domain
    )

    if (!(Test-Path "./workers")) {
        New-Item -ItemType Directory -Path "./workers"
    }

    $domainId   = $domain.id
    $domainName = $domain.name

    $response = Invoke-RestMethod -Uri ("{0}zones/{1}/workers/scripts" -f $CloudflareEndpoint, $domainId) -Method Get -Headers @{
        "X-Auth-Email" = $env:CLOUDFLARE_USER_EMAIL
        "X-Auth-Key"   = $env:CLOUDFLARE_API_KEY
        "Content-Type" = "application/json"
    }

    if ($null -eq $response.result) {
        Write-Host "No workers found for domain: $domainName"
        return
    }

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    foreach ($worker in $response.result) {
        $workerScript = Invoke-RestMethod -Uri ("{0}zones/{1}/workers/scripts/{2}" -f $CloudflareEndpoint, $domainId, $worker.id) -Method Get -Headers @{
            "X-Auth-Email" = $env:CLOUDFLARE_USER_EMAIL
            "X-Auth-Key"   = $env:CLOUDFLARE_API_KEY
            "Content-Type" = "application/json"
        }

        if ($workerScript) {
            $workerScript.script | Out-File -FilePath "./workers/${domainName}_${worker.id}_${timestamp}.js"
            Write-Host "Exported Worker script for domain: $domainName, script ID: $($worker.id)"
        } else {
            Write-Host "Error exporting Worker script for domain $domainName, script ID: $($worker.id)."
        }
    }
}

# Main Script

# Check environment
Check-Environment

# Fetch data from Cloudflare
Write-Host "Getting List of domains from Cloudflare"
Write-Host "======================================="

# Get domain names from Cloudflare
Get-Domains

# Export Domain Records and Worker Configurations
Write-Host "Writing domain DNS files and Worker configurations"
foreach ($domain in $domainList) {
    Export-DNS $domain
    Export-Worker $domain
}

Write-Host "Domain DNS records and Worker configurations complete. Please check the /domains and /workers directories for your files"
