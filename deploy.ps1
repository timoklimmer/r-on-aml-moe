# Deploys the R webservice defined in folder webservice to Azure Machine Learning.
# --------------------------------------------------------------------------------
# Requirements:
# - an Azure ML workspace
# - Azure CLI incl. ml extension installed (v2).
# - a local Docker instance (for dev/test before deploying to Azure)
# - a proper configuration, see webservice/config.psd1 file

Param(
    [Parameter(Mandatory = $False)]
    [switch]$AcceptConfiguration = $False,

    [Parameter(Mandatory = $False)]
    [switch]$DeployToAzure = $False
)

$ErrorActionPreference = "Stop"

# -- load configuration
Write-Host ">> Loading configuration..." -ForegroundColor DarkCyan
$config = Import-PowerShellDataFile -Path .\webservice\config.psd1
if (![string]::IsNullOrWhiteSpace($config.HTTP_PROXY)) {
    $env:HTTP_PROXY = $config.HTTP_PROXY
}
if (![string]::IsNullOrWhiteSpace($config.HTTPS_PROXY)) {
    $env:HTTP_PROXY = $config.HTTPS_PROXY
}
$config.GetEnumerator() | Sort-Object -Property key
Write-Host
if (!$AcceptConfiguration -and (!((Read-Host -Prompt "Do you want to continue with the configuration shown above? [y/n]") -match "[yY]"))) { 
    exit 1
}
Write-Host

# -- compute several required variable values
Write-Host ">> Computing several required variable values..." -ForegroundColor DarkCyan
$local_model_path = "$PWD/webservice"
$acr_name = $(az ml workspace show -g $($config.RESOURCE_GROUP) -w $($config.WORKSPACE) `
        --query container_registry -o tsv).split("/")[-1]
$image_tag = "$acr_name.azurecr.io/$($config.APP_NAME)" + ":latest"
$latest_model_version = 0
try {
    $latest_model_version = $(az ml model show -n $($config.MODEL_NAME) -g $($config.RESOURCE_GROUP) `
            -w $($config.WORKSPACE) --query version)
}
finally {
    $next_model_version = [int] $latest_model_version + 1
}

## LOCAL CONTAINER BUILD FOR TESTING
Write-Host "`nBuild and run local container..." -ForegroundColor Cyan

# -- locally build the docker image
Write-Host ">> Build the local docker image..." -ForegroundColor DarkCyan
$azureml_model_dir = "/var/azureml-app/azureml-models/$($config.MODEL_NAME)/$next_model_version/webservice"
Push-Location
Set-Location webservice
(Get-Content -Path Dockerfile.template) -replace "#PATH_TO_PLUMBER_R#", `
    """$azureml_model_dir/plumber.R""" `
| Set-Content -Path Dockerfile.temp
docker build -f Dockerfile.temp -t $image_tag --build-arg HTTP_PROXY=$($env:HTTP_PROXY) `
    --build-arg HTTPS_PROXY=$($env:HTTPS_PROXY) .
Remove-Item Dockerfile.temp
Pop-Location
Write-Host

# -- start the image locally
# notes: - if the image does not start, checking the logs of the container might help.
#          to see the log run "docker logs --tail 1000 <container id>" or simply use "View Logs" in VS.Code ;-)
#        - waiting some seconds to give the container some time to start
Write-Host ">> Starting the local docker image..." -ForegroundColor DarkCyan
& { docker rm -f -v $config.APP_NAME } -ErrorAction SilentlyContinue
docker run -d -p 8000:8000 -v ($local_model_path + ":$azureml_model_dir") `
    -e AZUREML_MODEL_DIR=$azureml_model_dir --name=$($config.APP_NAME) $image_tag
Start-Sleep -s 5

# TEST LOCAL IMAGE/ENDPOINTS
# note: added --noproxy localhost to ensure we don't run into proxy issues
Write-Host "`nTest local container..." -ForegroundColor Cyan
Write-Host ">> Live" -ForegroundColor DarkCyan
curl "http://localhost:8000/live" --noproxy localhost
Write-Host "`n`n>> Ready" -ForegroundColor DarkCyan
curl "http://localhost:8000/ready" --noproxy localhost
Write-Host "`n`n>> Score" -ForegroundColor DarkCyan
curl -H "Content-Type: application/json" --data "@webservice/sample_request.json" http://localhost:8000/score `
    --noproxy localhost
Write-Host "`n"

## DEPLOY TO AZURE
if (!$DeployToAzure -and (!((Read-Host -Prompt "Do you want to continue and deploy your container to Azure? [y/n]") -match "[yY]"))) { 
    exit 1
}
Write-Host "`nDeploy to Azure..." -ForegroundColor Cyan

Write-Host ">> Login to Azure..." -ForegroundColor DarkCyan
if (![string]::IsNullOrWhiteSpace($config.AZURE_SUBSCRIPTION_ID)) {
    az account set -s $($config.AZURE_SUBSCRIPTION_ID)
}

# -- deploy model(s)
Write-Host ">> Deploying model..." -ForegroundColor DarkCyan
az ml model create --name $($config.MODEL_NAME) --version $next_model_version --local-path $local_model_path `
    -g $($config.RESOURCE_GROUP) -w $($config.WORKSPACE)

# -- publish image to ACR
Write-Host "`n>> Pushing container image to Azure Container Registry..." -ForegroundColor DarkCyan
az acr login --name $acr_name
docker push $image_tag

# -- deploy endpoint to AML managed online endpoint
Write-Host "`n>> Creating/updating AML Managed Online Endpoint..." -ForegroundColor DarkCyan
$endpoint_exists = [System.Convert]::ToBoolean(
    $(az ml endpoint show -n $($config.UNIQUE_ENDPOINT_NAME) --query name -o tsv -g $($config.RESOURCE_GROUP) `
            -w $($config.WORKSPACE)) -eq $($config.UNIQUE_ENDPOINT_NAME)
)
if ($endpoint_exists -eq $false) {
    az ml endpoint create -f webservice/managedOnlineEndpoint.yml `
        -g $($config.RESOURCE_GROUP) -w $($config.WORKSPACE) `
        -n $($config.UNIQUE_ENDPOINT_NAME) `
        --set name=$($config.APP_NAME) `
        --set deployments[0].model.name=$($config.MODEL_NAME) `
        --set deployments[0].model.version=$next_model_version `
        --set deployments[0].environment.name=$($config.APP_NAME) `
        --set deployments[0].environment.docker.image=$image_tag `
        --set deployments[0].environment.docker.image=$image_tag `
        --set deployments[0].instance_type=$($config.INSTANCE_TYPE) `
        --set deployments[0].scale_settings.instance_count=$($config.INSTANCE_COUNT) `
        --set deployments[0].scale_settings.min_instances=$($config.INSTANCE_COUNT) `
        --set deployments[0].scale_settings.max_instances=$($config.INSTANCE_COUNT)
}
else {
    az ml endpoint update -f webservice/managedOnlineEndpoint.yml `
        -g $($config.RESOURCE_GROUP) -w $($config.WORKSPACE) `
        -n $($config.UNIQUE_ENDPOINT_NAME) `
        --set name=$($config.APP_NAME) `
        --set deployments[0].model.name=$($config.MODEL_NAME) `
        --set deployments[0].model.version=$next_model_version `
        --set deployments[0].environment.name=$($config.APP_NAME) `
        --set deployments[0].environment.docker.image=$image_tag `
        --set deployments[0].environment.docker.image=$image_tag `
        --set deployments[0].instance_type=$($config.INSTANCE_TYPE) `
        --set deployments[0].scale_settings.instance_count=$($config.INSTANCE_COUNT) `
        --set deployments[0].scale_settings.min_instances=$($config.INSTANCE_COUNT) `
        --set deployments[0].scale_settings.max_instances=$($config.INSTANCE_COUNT)
}

# -- check logs in case the deployment has failed
# az ml endpoint get-logs --name $($config.UNIQUE_ENDPOINT_NAME) --deployment default --lines 100 --resource-group $($config.RESOURCE_GROUP) --workspace-name $($config.WORKSPACE)

# -- get URI and credentials for endpoint
Write-Host "`n>> Getting scoring URI and authentication keys for webservice..." -ForegroundColor DarkCyan
$scoring_uri = $(az ml endpoint show -n $($config.UNIQUE_ENDPOINT_NAME) -g $($config.RESOURCE_GROUP) `
        -w $($config.WORKSPACE) --query "scoring_uri" -o tsv)
Write-Host "Scoring URI: $scoring_uri"
$primary_key = $(az ml endpoint get-credentials -n $($config.UNIQUE_ENDPOINT_NAME) -g $($config.RESOURCE_GROUP) `
        -w $($config.WORKSPACE) --query "primaryKey" -o tsv)
#Write-Host "Primary Key: $primary_key"

# -- test endpoint in Azure
Write-Host "`n>> Test webservice in Azure..." -ForegroundColor DarkCyan
if ([string]::IsNullOrWhiteSpace($config.HTTPS_PROXY)) {
    curl -H "Content-Type: application/json" -H "Authorization: Bearer $primary_key" `
        --data "@webservice/sample_request.json" $scoring_uri
}
else {
    curl -H "Content-Type: application/json" -H "Authorization: Bearer $primary_key" `
        --data "@webservice/sample_request.json" $scoring_uri `
        --proxy "$($config.HTTPS_PROXY)"
}
Write-Host

# -- done
Write-Host "`nDone."
