# This IaC script provisions and configures the web stite hosted in azure
# storage, the back end function and the cosmos db
#
[CmdletBinding()]
param(
    [Parameter(Mandatory = $True)]
    [string]
    $servicePrincipal,

    [Parameter(Mandatory = $True)]
    [string]
    $servicePrincipalSecret,

    [Parameter(Mandatory = $True)]
    [string]
    $servicePrincipalTenantId,

    [Parameter(Mandatory = $True)]
    [string]
    $azureSubscriptionName,

    [Parameter(Mandatory = $True)]
    [string]
    $resourceGroupName,

    [Parameter(Mandatory = $True)]
    [string]
    $resourceGroupNameRegion,

    [Parameter(Mandatory = $True)]  
    [string]
    $serverName,

    [Parameter(Mandatory = $True)]  
    [string]
    $dbLocation,

    [Parameter(Mandatory = $True)]  
    [string]
    $adminlogin,

    [Parameter(Mandatory = $True)]  
    [string]
    $adminPassword,
    
    [Parameter(Mandatory = $True)]  
    [string]
    $startip,

    [Parameter(Mandatory = $True)]  
    [string]
    $endip,

    [Parameter(Mandatory = $True)]  
    [string]
    $dbName,

    [Parameter(Mandatory = $True)]  
    [string]
    $webAppName,

    [Parameter(Mandatory = $True)]  
    [string]
    $environment
)


#region Login

# This logs in a service principal
#
Write-Output "Logging in to Azure with a service principal..."
az login `
    --service-principal `
    --username $servicePrincipal `
    --password $servicePrincipalSecret `
    --tenant $servicePrincipalTenantId
Write-Output "Done"
Write-Output ""

# This sets the subscription to the subscription I need all my apps to
# run in
#
Write-Output "Setting default azure subscription..."
az account set `
    --subscription $azureSubscriptionName
Write-Output "Done"
Write-Output ""
#endregion

# this defines my time 1 up function which will deploy and configure the infrastructure 
# for my web app service and sql server
#
function 1_Up {
    Write-Output "In function 1_Up"

    #region Create Resource Group
    # # This creates the resource group used to house all of Mercury Health
    # #
    Write-Output "Creating resource group $resourceGroupName in region $resourceGroupNameRegion..."
    az group create `
        --name $resourceGroupName `
        --location $resourceGroupNameRegion
    Write-Output "Done creating resource group"
    Write-Output ""
    #endregion



    #region Create Sql Server and database
    # Create a logical sql server in the resource group
    # 
    Write-Output "Creating sql server..."
    try {
        az sql server create `
        --name $serverName `
        --resource-group $resourceGroupName `
        --location $dbLocation  `
        --admin-user $adminlogin `
        --admin-password $adminPassword
    }
    catch {
        Write-Output "SQL Server already exists"
    }
    Write-Output "Done creating sql server"
    Write-Output ""

    # Configure a firewall rule for the server
    #
    Write-Output "Creating firewall rule for sql server..."
    try {
        az sql server firewall-rule create `
        --resource-group $resourceGroupName `
        --server $serverName `
        -n AllowYourIp `
        --start-ip-address $startip `
        --end-ip-address $endip 
    }
    catch {
        Write-Output "firewall rule already exists"
    }
    Write-Output "Done creating firewall rule for sql server"
    Write-Output ""

    # Create a database in the server with zone redundancy as false
    #
    Write-Output "Create sql db $dbName..."
    try {
        az sql db create `
        --resource-group $resourceGroupName `
        --server $serverName `
        --name $dbName `
        --edition GeneralPurpose `
        --family Gen4 `
        --zone-redundant false `
        --capacity 1
    }
    catch {
        Write-Output "sql db already exists"
    }
    Write-Output "Done creating sql db"
    Write-Output ""
    #endregion



    #region create app service
    # create app service plan
    #
    Write-Output "creating app service plan..."
    try {
        az appservice plan create `
        --name $("$webAppName" + "plan") `
        --resource-group $resourceGroupName `
        --sku S1
    }
    catch {
        Write-Output "app service already exists."
    }
    Write-Output "done creating app service plan"
    Write-Output ""

    Write-Output "creating web app..."
    try {
        az webapp create `
        --name $webAppName `
        --plan $("$webAppName" + "plan") `
        --resource-group $resourceGroupName

    }
    catch {
        Write-Output "web app already exists"
    }
    Write-Output "done creating web app"
    Write-Output ""

    Write-Output "Setting connection string.."
    az webapp config connection-string set `
        --name $webAppName `
        --connection-string-type "SQLAzure" `
        --resource-group $resourceGroupName `
        --settings DefaultConnection="Server=tcp:$serverName.database.windows.net,1433;Initial Catalog=$dbName;Persist Security Info=False;User ID=$adminLogin;Password=$adminPassword;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"

    Write-Output "Done setting connection string"
    Write-Output ""

    Write-Output "Setting environment string.."
    az webapp config appsettings set `
        --name $webAppName `
        --resource-group $resourceGroupName `
        --settings Environment="$environment"
    Write-Output "Done setting environment string"
    Write-Output ""
    #endregion



    #region create application insights for web app
    # this creates an instance of appliction insight for node 1
    #
    Write-Output "creating application insight for web app..."
    $appInsightCreateResponse=$(az resource create `
        --resource-group $resourceGroupName `
        --resource-type "Microsoft.Insights/components" `
        --name $($webAppName + "AppInsight") `
        --properties '{\"Application_Type\":\"web\"}') | ConvertFrom-Json
    Write-Output "done creating app insight for node 1: $appInsightCreateResponse"
    Write-Output ""

    # this gets the instrumentation key from the create response
    #
    Write-Output "getting instrumentation key from the create response..."
    $instrumentationKey = $appInsightCreateResponse.properties.InstrumentationKey
    Write-Output "done getting instrumentation key"
    Write-Output ""

    # this sets application insight to web app
    #
    Write-Output "setting and configuring application insight for webapp..."
    az webapp config appsettings set `
        --resource-group $resourceGroupName `
        --name $webAppName `
        --slot-settings APPINSIGHTS_INSTRUMENTATIONKEY=$instrumentationKey `
                        ApplicationInsightsAgent_EXTENSION_VERSION=~2 `
                        XDT_MicrosoftApplicationInsights_Mode=recommended `
                        APPINSIGHTS_PROFILERFEATURE_VERSION=1.0.0 `
                        DiagnosticServices_EXTENSION_VERSION=~3 `
                        APPINSIGHTS_SNAPSHOTFEATURE_VERSION=1.0.0 `
                        SnapshotDebugger_EXTENSION_VERSION=~1 `
                        InstrumentationEngine_EXTENSION_VERSION=~1 `
                        XDT_MicrosoftApplicationInsights_BaseExtension=~1
    Write-Output "done setting and configuring application insight for web app"
    Write-Output ""
    #endregion
}

Install-Module -Name VersionInfrastructure -Force -Scope CurrentUser
Update-InfrastructureVersion `
    -infraToolsFunctionName $Env:INFRATOOLS_FUNCTIONNAME `
    -infraToolsTableName $Env:INFRATOOLS_TABLENAME `
    -deploymentStage $Env:INFRATOOLS_DEPLOYMENTSTAGE