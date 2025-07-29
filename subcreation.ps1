<#
.SYNOPSIS
    Creates a new MCA subscription across tenants using Microsoft's official two-phase method.

.DESCRIPTION
    This script implements Microsoft's official approach for creating MCA subscriptions
    across Microsoft Entra tenants using a two-phase process with subscription alias creation
    and ownership acceptance.

.PARAMETER SubscriptionName
    The name of the subscription to create (e.g., "map-application-weu-prd")

.PARAMETER Workload
    The workload type for the subscription (Production or Development)

.EXAMPLE
    .\subcreation.ps1 -SubscriptionName "map-application-weu-prd" -Workload "Production"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionName,
    
    [Parameter(Mandatory=$false)]  
    [ValidateSet("Production", "Development")]
    [string]$Workload = "Production"
)

# Validate environment variables
$requiredVars = @(
    'SOURCE_TENANT_ID',
    'SOURCE_CLIENT_ID', 
    'SOURCE_CLIENT_SECRET',
    'DEST_TENANT_ID',
    'DEST_CLIENT_ID',
    'DEST_CLIENT_SECRET', 
    'DEST_SERVICE_PRINCIPAL_ID',
    'BILLING_ACCOUNT_ID',
    'BILLING_PROFILE_ID',
    'INVOICE_SECTION_NAME'
)

foreach ($var in $requiredVars) {
    if (-not (Get-Item "env:$var" -ErrorAction SilentlyContinue)) {
        throw "Required environment variable $var is not set"
    }
}

# Configuration from environment variables
$sourceTenantId = $env:SOURCE_TENANT_ID
$sourceClientId = $env:SOURCE_CLIENT_ID
$sourceClientSecret = $env:SOURCE_CLIENT_SECRET
$destTenantId = $env:DEST_TENANT_ID
$destClientId = $env:DEST_CLIENT_ID
$destClientSecret = $env:DEST_CLIENT_SECRET
$destServicePrincipalId = $env:DEST_SERVICE_PRINCIPAL_ID
$billingAccountId = $env:BILLING_ACCOUNT_ID
$billingProfileId = $env:BILLING_PROFILE_ID
$invoiceSectionName = $env:INVOICE_SECTION_NAME

Write-Output "========================================="
Write-Output "MCA Cross-Tenant Subscription Creation"
Write-Output "========================================="
Write-Output "Subscription Name: $SubscriptionName"
Write-Output "Workload: $Workload"
Write-Output "Source Tenant: $sourceTenantId"
Write-Output "Destination Tenant: $destTenantId"
Write-Output "Billing Profile: $billingProfileId"
Write-Output "========================================="

# Function to get access token
function Get-AccessToken {
    param($TenantId, $ClientId, $ClientSecret)
    
    $body = @{
        grant_type = "client_credentials"
        client_id = $ClientId
        client_secret = $ClientSecret
        resource = "https://management.azure.com/"
    }
    
    try {
        $response = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$TenantId/oauth2/token" -Method Post -Body $body
        return $response.access_token
    }
    catch {
        throw "Failed to get access token for tenant $TenantId : $($_.Exception.Message)"
    }
}

Write-Output "Phase 1: Create Subscription Alias in Source Tenant"
Write-Output "Step 1: Authenticating with source tenant..."

# Get access token for source tenant
$sourceToken = Get-AccessToken -TenantId $sourceTenantId -ClientId $sourceClientId -ClientSecret $sourceClientSecret
Write-Output "✓ Source tenant authentication successful"

Write-Output "Step 2: Looking up invoice section ID..."
# Get the invoice section ID  
$invoiceSectionsUri = "https://management.azure.com/providers/Microsoft.Billing/billingAccounts/$billingAccountId/billingProfiles/$billingProfileId/invoiceSections?api-version=2020-05-01"
$headers = @{
    'Authorization' = "Bearer $sourceToken"
    'Content-Type' = 'application/json'
}

try {
    $invoiceSections = Invoke-RestMethod -Uri $invoiceSectionsUri -Method Get -Headers $headers
    $invoiceSection = $invoiceSections.value | Where-Object { $_.properties.displayName -eq $invoiceSectionName }

    if (-not $invoiceSection) {
        $availableSections = $invoiceSections.value | ForEach-Object { $_.properties.displayName } | Join-String ', '
        throw "Invoice section '$invoiceSectionName' not found. Available sections: $availableSections"
    }

    $invoiceSectionId = $invoiceSection.name
    Write-Output "✓ Found invoice section: $invoiceSectionName (ID: $invoiceSectionId)"
}
catch {
    throw "Failed to get invoice sections: $($_.Exception.Message)"
}

Write-Output "Step 3: Creating subscription alias..."

# Generate a unique alias ID (GUID)
$aliasId = [System.Guid]::NewGuid().ToString()
$billingScope = "/billingAccounts/$billingAccountId/billingProfiles/$billingProfileId/invoiceSections/$invoiceSectionId"

# Create subscription alias using Microsoft's official API
$aliasUri = "https://management.azure.com/providers/Microsoft.Subscription/aliases/$aliasId" + "?api-version=2021-10-01"

$aliasBody = @{
    properties = @{
        displayName = $SubscriptionName
        workload = $Workload
        billingScope = $billingScope
        subscriptionId = $null
        additionalProperties = @{
            managementGroupId = $null
            subscriptionTenantId = $destTenantId
            subscriptionOwnerId = $destServicePrincipalId
        }
    }
} | ConvertTo-Json -Depth 10

Write-Output "Creating subscription alias with ID: $aliasId"
Write-Output "Billing scope: $billingScope"

try {
    $aliasResponse = Invoke-RestMethod -Uri $aliasUri -Method Put -Headers $headers -Body $aliasBody
    
    # Extract subscription ID from location header or response
    $subscriptionId = $null
    if ($aliasResponse.properties.subscriptionId) {
        $subscriptionId = $aliasResponse.properties.subscriptionId
    }
    
    Write-Output "✓ Subscription alias created successfully"
    Write-Output "Alias ID: $aliasId"
    Write-Output "Subscription ID: $subscriptionId"
    Write-Output "Status: $($aliasResponse.properties.provisioningState)"
}
catch {
    $errorDetails = ""
    if ($_.Exception.Response) {
        try {
            $errorStream = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($errorStream)
            $errorDetails = $reader.ReadToEnd()
        }
        catch {
            $errorDetails = "Unable to read error details"
        }
    }
    
    Write-Error "Failed to create subscription alias:"
    Write-Error "Error: $($_.Exception.Message)"
    Write-Error "Details: $errorDetails"
    throw
}

Write-Output ""
Write-Output "Phase 2: Accept Ownership in Destination Tenant"
Write-Output "Step 4: Authenticating with destination tenant..."

# Get access token for destination tenant
$destToken = Get-AccessToken -TenantId $destTenantId -ClientId $destClientId -ClientSecret $destClientSecret
Write-Output "✓ Destination tenant authentication successful"

Write-Output "Step 5: Accepting subscription ownership..."

# Accept ownership in destination tenant
$acceptOwnershipUri = "https://management.azure.com/providers/Microsoft.Subscription/subscriptions/$subscriptionId/acceptOwnership?api-version=2021-10-01"

$destHeaders = @{
    'Authorization' = "Bearer $destToken"
    'Content-Type' = 'application/json'
}

$acceptBody = @{
    properties = @{
        displayName = $SubscriptionName
        managementGroupId = $null
    }
} | ConvertTo-Json -Depth 10

try {
    $acceptResponse = Invoke-RestMethod -Uri $acceptOwnershipUri -Method Post -Headers $destHeaders -Body $acceptBody
    
    Write-Output "========================================="
    Write-Output "✓ MCA SUBSCRIPTION CREATED SUCCESSFULLY!"
    Write-Output "========================================="
    Write-Output "Subscription ID: $subscriptionId"
    Write-Output "Subscription Name: $SubscriptionName"
    Write-Output "Workload: $Workload"
    Write-Output "Source Tenant: $sourceTenantId"
    Write-Output "Destination Tenant: $destTenantId"
    Write-Output "Billing Account: $billingAccountId"
    Write-Output "Billing Profile: $billingProfileId"
    Write-Output "Invoice Section: $invoiceSectionName"
    Write-Output "========================================="
    
    # Set pipeline variables for downstream tasks
    Write-Output "##vso[task.setvariable variable=CreatedSubscriptionId]$subscriptionId"
    Write-Output "##vso[task.setvariable variable=CreatedSubscriptionName]$SubscriptionName"
    Write-Output "##vso[task.setvariable variable=CreatedSubscriptionStatus]Succeeded"
    
    return @{
        SubscriptionId = $subscriptionId
        SubscriptionName = $SubscriptionName
        Status = "Succeeded"
        Workload = $Workload
        SourceTenantId = $sourceTenantId
        DestinationTenantId = $destTenantId
        BillingAccountId = $billingAccountId
        BillingProfileId = $billingProfileId
        InvoiceSectionId = $invoiceSectionId
    }
}
catch {
    $errorDetails = ""
    if ($_.Exception.Response) {
        try {
            $errorStream = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($errorStream)
            $errorDetails = $reader.ReadToEnd()
        }
        catch {
            $errorDetails = "Unable to read error details"
        }
    }
    
    Write-Error "========================================="
    Write-Error "✗ Failed to accept subscription ownership"
    Write-Error "========================================="
    Write-Error "Subscription ID: $subscriptionId"
    Write-Error "Error: $($_.Exception.Message)"
    Write-Error "Details: $errorDetails"
    Write-Error "========================================="
    
    # The subscription was created but ownership wasn't accepted
    # Set variables to indicate partial success
    Write-Output "##vso[task.setvariable variable=CreatedSubscriptionId]$subscriptionId"
    Write-Output "##vso[task.setvariable variable=CreatedSubscriptionName]$SubscriptionName"
    Write-Output "##vso[task.setvariable variable=CreatedSubscriptionStatus]PartialSuccess"
    
    throw "Subscription created but ownership acceptance failed. Manual intervention may be required."
}
