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
    $adminLogin,

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


#region function to upload default data
# this function uploads default data to a table
#
function Upload-DefaultData {
    param(
        [Parameter(Mandatory = $True)]
        [string]
        $dbServerName,

        [Parameter(Mandatory = $True)]
        [string]
        $dbId,

        [Parameter(Mandatory = $True)]
        [string]
        $userId,

        [Parameter(Mandatory = $True)]
        [string]
        $userPassword,

        [Parameter(Mandatory = $True)]
        [string]
        $uploadFile,

        [Parameter(Mandatory = $True)]
        [string]
        $tableName
    )
    Write-Output "Checking data for $tableName..."
    $numRows=$(Invoke-Sqlcmd -ConnectionString "Server=tcp:$dbServerName.database.windows.net,1433;Initial Catalog=$dbId;Persist Security Info=False;User ID=$userId;Password=$userPassword;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;" `
        -Query "SELECT Count(*) FROM $tableName" `
    )
    if ($numRows.Column1 -eq 0) {
        Write-Output "No data for $tableName, loading default data..."
        $fullDbName = $dbId + ".dbo." + $tableName
        $fullServerName = $dbServerName + ".database.windows.net"
        & "C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\bcp" $fullDbName in $releaseDirectory\_MercuryHealthFull-CI\web\data\$uploadFile -S $fullServerName -U $userId -P "$userPassword" -q -c -t "," -F 2
        Write-Output "done upload default data for $tableName"
    }
    else {
        Write-Output "Data already exists for $tableName"
    }    
    Write-Output "done checking data for $tableName"
    Write-Output ""
}
#endregion


# this defines my time 1 up function which will deploy and configure the infrastructure 
# for my web app service and sql server
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
        --admin-user $adminLogin `
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
    
    Write-Output "Done with function 1_Up"
}

# this defines my time 2 up fuction which will set up and restore database from backups
function 2_UP {
    Write-Output "In function 2_Up"

    #region create db tables
    # this block creates the initial tables if needed
    #
    Write-Output "creating db tables..."
    Invoke-Sqlcmd `
        -ConnectionString "Server=tcp:$($serverName).database.windows.net,1433;Initial Catalog=$dbName;Persist Security Info=False;User ID=$adminLogin;Password=$adminPassword;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;" `
        -Query "IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='FoodLogEntries' and xtype='U') CREATE TABLE Courses ( Id INT IDENTITY (1, 1) NOT NULL, Description NVARCHAR (MAX) NULL, Quantity REAL NOT NULL, MealTime DATETIME NOT NULL, Tags NVARCHAR (MAX) NULL, Calories INT NOT NULL, ProteinInGrams DECIMAL (18, 2) NOT NULL, FatInGrams DECIMAL (18, 2) NOT NULL, CarbohydratesInGrams DECIMAL (18, 2) NOT NULL, SodiumInGrams DECIMAL (18, 2) NOT NULL, MemberProfile_Id INT NULL, Color NVARCHAR(50) NULL, );"
    Write-Output "done creating db tables"
    Write-Output ""
    
    Write-Output "restoring data from backup..."
    Upload-DefaultData -dbServerName $serverName -dbId $dbName -userId $adminLogin -userPassword $adminPassword -uploadFile "FoodLogEntries-beta.csv" -tableName FoodLogEntries
    Write-Output "done restoring data from backup..."
    #endregion

    Write-Output "Done with function 2_Up"
}

Install-Module -Name VersionInfrastructure -Force -Scope CurrentUser
Update-InfrastructureVersion `
    -infraToolsFunctionName $Env:INFRATOOLS_FUNCTIONNAME `
    -infraToolsTableName $Env:INFRATOOLS_TABLENAME `
    -deploymentStage $Env:INFRATOOLS_DEPLOYMENTSTAGE