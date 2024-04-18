param
(
    [string]$dbServer = "",
    [string]$dbName = "",
    [string]$dbUser = "",
    [string]$dbPassword = "",
    [string]$createBucket = "",
    [string]$containername = "",
    [string]$bucketName = "",
    [string]$tables = "",
    [string]$isMinio = ""
)

function Move-DataToAWS([string]$tableName, [string]$primaryKeyColumnName, [string]$contentColumnName, [bool]$isIdColumnInt = $true) {
    "Running Move Data Function"
$hasResults = 1;
while ($hasResults -eq 1) {
    $totalItemsToImport = $msmDatabase.ExecuteWithResults("SELECT COUNT(*) as totalItems FROM $tableName WHERE externalStorageProvider like '%S3%';").Tables[0].totalItems
    
    $totalItems = 100;
    if ($totalItems -gt 0) { 
         "Translating $tableName data to Azure storage..."
    } else {
         "Found no data to move in $tableName table"
        return
    }
    
    $progress = 0;
    $failedCount = 0;
    $successCount = 0;

    $results = $msmDatabase.ExecuteWithResults("SELECT TOP (100) $primaryKeyColumnName AS id, $contentColumnName AS content FROM $tableName WHERE requestId = '105' AND externalStorageProvider like '%S3%';")
    if ($results) {
    $results.Tables[0] | ForEach-Object {
        $id = $_.id
        $content = $_.content
        "Have content as $content"

        $jsonObject = ConvertFrom-Json $content
        
        $jsonObject.Type = "AzureBlob"
        $jsonObject.PSObject.Properties.Add('ServiceUrl')
        
        
        $bucketname = $jsonObject.BucketName
        $jsonObject.ServiceUrl = "https://$containername.core.windows.net/$bucketname"
        
        # Remove unnecessary properties
        $jsonObject.PSObject.Properties.Remove('Region')
        $jsonObject.PSObject.Properties.Remove('ForcePathStyle')
        
        # Output the updated JSON object
        "Json object is $jsonObject"
        $newJsonString = $jsonObject | ConvertTo-Json


        "New mutated string is $newJsonString"
         exit;
        # $externalStorageProvider = "{`"Type`":`"S3`",`"ExternalStorageKey`":`"$guid`",`"BucketName`":`"$bucketName`",`"Region`":{`"SystemName`":`"$($region.Region)`",`"DisplayName`":`"$($region.Name)`"}}"
        try {
			
			#if($isIdColumnInt) {
                "Updating $tableName with content column as $contentColumnName json string $newJsonString primary key column name is $primaryKeyColumnName  "
		      $msmDatabase.ExecuteNonQuery("UPDATE $tableName SET $contentColumnName = '$newJsonString' WHERE $primaryKeyColumnName = $id");
              exit;
			# else {
			#	$msmDatabase.ExecuteNonQuery("UPDATE $tableName SET $contentColumnName = NULL, externalStorageProvider = '$externalStorageProvider' WHERE $primaryKeyColumnName = '$id'")
			#
			
			$successCount++
        } catch {
            $failedCount++;
            echo "An exception occured while proccessing $primaryKeyColumnName - {$id}: $_"
        } finally {
            $progress++;
            $percentageComplete = ($progress / $totalItems) * 100
           # Write-Progress -Activity "Move in Progress" -Status "$percentageComplete% Complete:" -PercentComplete $percentageComplete;
        }
    }
    echo "Total items are $totalItemsToImport";
    if ($totalItemsToImport -gt 0) {
        echo "Move completed. Successfully moved $successCount/$totalItems rows to storage, now have $totalItemsToImport rows left to transfer..."
    } else {
     $hasResults = 0;
    }
    }
}
}

# ensure we're elevated
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (!$isAdmin) {
    try {
        # we're not running elevated - so try to relaunch as administrator
        echo "Starting elevated PowerShell instance."
        $newProcess = New-Object System.Diagnostics.ProcessStartInfo "PowerShell"
        $newProcess.Arguments = @("-NoProfile","-NoLogo", $myInvocation.MyCommand.Definition, "-containerName `"$containername`" -dbServer `"$dbServer`" -dbName `"$dbName`" -dbUser `"$dbUser`" -dbPassword `"$dbPassword`" -tables `"$tables`"")
        $newProcess.Verb = "runas"
        [System.Diagnostics.Process]::Start($newProcess)
    }
    catch {
        echo "Unable to start elevated PowerShell instance."
    }
    finally {
        # always exit this script either we're now running a separate elevated power shell or we've had an error
        exit
    }
}

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]"Ssl3,Tls,Tls11,Tls12"

# ensure we have the Microsoft.SqlServer.Smo module installed
$sqlServerModules = Get-Module -ListAvailable -Name SqlServer

if ($sqlServerModules) {
    Import-Module SqlServer
}

[Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo") | Out-Null

if (!$sqlServerModules) {
    try {
        New-Object Microsoft.SqlServer.Management.SMO.Database | Out-Null
    } catch {
        echo "Installing SqlServer module..."
        Install-Module SqlServer -Scope CurrentUser
        Import-Module SqlServer
        [Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo") | Out-Null
    }
}

# ensure we have the AWS CLI installed

# ensure we have the AWSPowerShell module installed
$awsPowerShellModules = Get-Module -ListAvailable -Name AWSPowerShell

if ($awsPowerShellModules) {
    Import-Module AWSPowerShell
}

if (!$awsPowerShellModules) {
    try {
        Set-AWSCredential
    } catch {
        echo "Installing AWSPowerShell module..."
        Install-Module AWSPowerShell -Scope CurrentUser
        Import-Module AWSPowerShell
    }
}

# ensure db credentials are specified
if (!$dbServer -or !$dbName -or !$dbUser) {
    echo "-dbServer, -dbName and -dbUser MUST be specified!"
    exit
}

# ensure tables are specified
if(!$tables) {
    echo "Please specify tables to specify which table/s you would like to work on."
    exit
}

"Connecting with server $dbServer username $dbUser passsword $dbPassword server $dbServer dname $dbName"

$server = New-Object Microsoft.SqlServer.Management.SMO.Server(New-Object Microsoft.SqlServer.Management.Common.ServerConnection($dbServer, $dbUser, $dbPassword))
$msmDatabase = New-Object Microsoft.SqlServer.Management.SMO.Database($server, $dbName)

$tableArray = $tables.Split(",")
Foreach ($table in $tableArray) {
    switch($table) {
        "queuedNotification" { Move-DataToAWS -tableName queuedNotification -primaryKeyColumnName queuedNotificationId -contentColumnName externalStorageProvider }
        "attachment" { Move-DataToAWS -tableName attachment -primaryKeyColumnName attachmentId -contentColumnName externalStorageProvider }
		"note" { Move-DataToAWS -tableName note -primaryKeyColumnName noteIdentifier -contentColumnName externalStorageProvider }
		"richTextImage" { Move-DataToAWS -tableName richTextImage -primaryKeyColumnName fileName -contentColumnName externalStorageProvider  }
    }
}
