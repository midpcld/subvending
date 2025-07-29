# MCA Cross-Tenant Subscription Creation

Programmatically create Microsoft Customer Agreement (MCA) subscriptions across Microsoft Entra tenants using Microsoft's official two-phase method.

## 🎯 Overview

This solution enables automated creation of Azure subscriptions in a destination tenant while billing them to a source tenant's MCA account. 

## 🏗️ How It Works

The solution implements Microsoft's official two-phase cross-tenant subscription creation process:

### Phase 1: Create Subscription Alias (Source Tenant)
1. **Authenticate** with source tenant using app credentials
2. **Lookup** invoice section ID by name
3. **Create subscription alias** using Microsoft.Subscription/aliases API
4. **Specify** destination tenant and service principal as owner

### Phase 2: Accept Ownership (Destination Tenant)
1. **Authenticate** with destination tenant using app credentials  
2. **Accept subscription ownership** using acceptOwnership API
3. **Finalize** subscription in destination tenant


## 📋 Prerequisites

### 1. App Registration in Source Tenant

Create an app registration with billing permissions:

- **Name:** `MCA-Subscription-Creator-Source`
- **Required Information:** Directory ID, Application ID, Client Secret
- **Billing Role:** Appropriate billing role assignment at billing account/profile/invoice section scope

### 2. App Registration in Destination Tenant 

Create an app registration with Billing Administrator role:

- **Name:** `MCA-Subscription-Creator`  
- **Required Information:** Directory ID, Application ID, Client Secret, Service Principal Object ID
- **Microsoft Entra Role:** Billing Administrator

### 3. Get Destination Service Principal ID

Required for specifying subscription owner:

```powershell
Get-AzADServicePrincipal -ApplicationId [dest-app-client-id] | Select-Object -Property Id
```

### 4. Copy this repository to your DevOps Project

### 5. Follow the Quick Start section next. 

## 🚀 Quick Start

### 1. Configure Azure DevOps Variables

Create/modify variable group `MCA-Billing-Variables` if necessary:

| Variable | Value | Secret |
|----------|-------|--------|
| `SOURCE_TENANT_ID` | Your source tenant ID | No |
| `SOURCE_CLIENT_ID` | Your source app client ID | No |
| `SOURCE_CLIENT_SECRET` | Your source app client secret | ✅ Yes |
| `DEST_TENANT_ID` | Your destination tenant ID | No |
| `DEST_CLIENT_ID` | Your destination app client ID | No |
| `DEST_CLIENT_SECRET` | Your destination app client secret | ✅ Yes |
| `DEST_SERVICE_PRINCIPAL_ID` | Destination app service principal object ID | No |
| `BILLING_ACCOUNT_ID` | Your billing account ID | No |
| `BILLING_PROFILE_ID` | Your billing profile ID | No |
| `INVOICE_SECTION_NAME` | Your invoice section name | No |

### 2. Create the Pipeline

1. Navigate to your Azure Devops Pipelines
2. Select New Pipeline
3. Select Azure Repos Git
4. Select your repository
5. Select Existing Azure Pipelines YAML file
6. Select /pipeline-subcreation.yml
7. Save (dropdown next to Run)

### 3. Run the Pipeline

1. Navigate to your Azure DevOps pipeline
2. Click **"Run pipeline"**
3. Enter subscription name (e.g., `map-application-weu-prd`)
4. Select workload type (`Production` or `Development`)
5. Execute
6. You will be prompted to add permissions to pipeline/repo, make sure you grant them

## 📁 Repository Structure

```
/
├── subcreation.ps1          # Main PowerShell script
├── azure-pipelines.yml     # Azure DevOps pipeline definition
├── README.md               # This file
```

## 🔧 Files Description

### `subcreation.ps1`
The main PowerShell script that implements Microsoft's two-phase cross-tenant subscription creation:

- **Input:** Subscription name, workload type
- **Output:** Created subscription ID, status, billing information
- **Features:** Comprehensive error handling, detailed logging, pipeline variable integration

### `azure-pipelines.yml`  
Azure DevOps pipeline definition with:

- **Parameters:** Subscription name, workload type selection
- **Steps:** Script execution, result validation, build tagging
- **Variables:** Secure variable group integration

## 🎮 Usage Examples

### Basic Usage
```yaml
# Pipeline parameters
subscriptionName: "map-application-weu-prd"
workload: "Production"
```

### Local Testing (if needed)
```powershell
# Set environment variables
$env:SOURCE_TENANT_ID = "yoursourceid"
# ... (set other variables)

# Run script
.\subcreation.ps1 -SubscriptionName "map-application-weu-prd" -Workload "Development"
```

## 📊 Expected Output

### Successful Execution
```
=========================================
MCA Cross-Tenant Subscription Creation
=========================================
Subscription Name: map-application-weu-prd
Workload: Production
Source Tenant: sourcetenantid
Destination Tenant: destinationtenantid
=========================================
Phase 1: Create Subscription Alias in Source Tenant
Step 1: Authenticating with source tenant...
✓ Source tenant authentication successful
Step 2: Looking up invoice section ID...
✓ Found invoice section: InvoiceSection (ID: ABC123...)
Step 3: Creating subscription alias...
✓ Subscription alias created successfully

Phase 2: Accept Ownership in Destination Tenant  
Step 4: Authenticating with destination tenant...
✓ Destination tenant authentication successful
Step 5: Accepting subscription ownership...
=========================================
✓ MCA SUBSCRIPTION CREATED SUCCESSFULLY!
=========================================
Subscription ID: abcd1234-5678-90ef-ghij-klmnopqrstuv
Subscription Name: map-application-weu-prd
Workload: Production
Source Tenant: sourcetenantid
Destination Tenant: destinationtenantid
=========================================
```

### Pipeline Variables Set
After successful execution, these variables are available for downstream tasks:

- `CreatedSubscriptionId`: The new subscription ID
- `CreatedSubscriptionName`: The subscription name
- `CreatedSubscriptionStatus`: Success status (`Succeeded`, `PartialSuccess`, `Failed`)

### Build Tags
The pipeline automatically adds these build tags (with safe formatting):

- `subscription_[subscription-name]`: Subscription identifier
- `tenant_desttenant`: Target tenant
- `status_[status]`: Creation status

## 🔒 Security Features

- **Dual Authentication:** Separate app credentials for each tenant
- **Least Privilege:** Minimal required permissions for each app
- **Secret Management:** Secure variable groups for sensitive data
- **Audit Trail:** Comprehensive logging of all operations
- **Error Isolation:** Phase separation prevents partial failures

## ⚡ Script Features

### Error Handling
- **Phase-specific errors:** Clear identification of which phase failed
- **Partial success handling:** Subscription created but ownership not accepted
- **Detailed error messages:** Full API response details for troubleshooting
- **Graceful degradation:** Pipeline continues with appropriate status

### Logging & Monitoring
- **Step-by-step progress:** Clear visual indicators for each phase
- **Pipeline integration:** Sets Azure DevOps variables for downstream tasks
- **Build summaries:** Automated tagging and build information
- **Audit trail:** Complete record of subscription creation process

### Validation
- **Environment variable validation:** Ensures all required variables are set
- **Invoice section lookup:** Verifies billing configuration before creation
- **Service principal validation:** Confirms destination app exists and is accessible
- **API response validation:** Checks for successful API calls at each step

## 🛠️ Troubleshooting

### Debug Mode

For detailed debugging, add debug parameters:

```powershell
.\subcreation.ps1 -SubscriptionName "debug-test" -Workload "Development" -Verbose
```

## 📚 Additional Resources

### Microsoft Documentation
- [Programmatically create MCA subscriptions across tenants](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/programmatically-create-subscription-microsoft-customer-agreement-across-tenants)
- [Understanding Microsoft Customer Agreement administrative roles](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/understand-mca-roles)
- [Microsoft Entra ID built-in roles](https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/permissions-reference)

### Azure DevOps Resources
- [Variable Groups](https://docs.microsoft.com/en-us/azure/devops/pipelines/library/variable-groups)
- [Pipeline Tasks](https://docs.microsoft.com/en-us/azure/devops/pipelines/tasks/)
- [Build Tags](https://docs.microsoft.com/en-us/azure/devops/pipelines/build/variables)

### PowerShell Resources
- [Microsoft Graph PowerShell](https://docs.microsoft.com/en-us/powershell/microsoftgraph/)
- [Azure PowerShell](https://docs.microsoft.com/en-us/powershell/azure/)

## Kudos

Thanks Justin Venter for the guidelines! 

## Disclaimer

Created by: midp.cloud

This project is provided as-is to simplify Microsoft's official subvending guidelines. It is offered free of charge with no support, warranty, or guarantee of any kind.
Use at your own risk. The creator assumes no responsibility for any issues, damages, or consequences arising from the use of this project.

This is an unofficial simplification - always refer to Microsoft's official documentation for authoritative guidance.
