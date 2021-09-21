# Walks through deploying an R model to a Managed Online Endpoint in Azure ML.
# ----------------------------------------------------------------------------
# Requirements:
# - an Azure ML workspace
# - Azure CLI incl. ml extension installed (v2).
#   IMPORTANT: This script will NOT work with the azure-cli-ml extension, which is v1.
#              Run "az version" to find out which version you have installed. use
#              "az extension remove/add --name <name>" to remove or add extensions as needed.
# - a local Docker instance (for dev/test before deploying to Azure)

$ErrorActionPreference = "Stop"

# -- configuration
# note: - if your company requires a proxy to reach out to the internet, you need to set the following variables, too.
#       - in that case, you also need to configure Docker to use the proxy.
#$env:HTTP_PROXY = "..."
#$env:HTTPS_PROXY = "..."

$RESOURCE_GROUP = "AzureMLSpikesAndDemos"
$WORKSPACE = "AzureMLSpikesAndDemos"

$APP_NAME = "r-on-aml-moe"
$UNIQUE_ENDPOINT_NAME = "$APP_NAME-ge7p4dmt"  # ensure that the postfix is unique
$CONTAINER_MODEL_NAME = "r-on-aml-moe"
$LOCAL_CONTAINER_MODEL_PATH = "$PWD/models"

# -- get some required variable values
$acr_name = $(az ml workspace show -g $RESOURCE_GROUP -w $WORKSPACE --query container_registry -o tsv).split("/")[-1]
$image_tag = "$acr_name.azurecr.io/$APP_NAME" + ":latest"
$latest_model_version = 0
try {
    $latest_model_version = $(az ml model show -n $CONTAINER_MODEL_NAME -g $RESOURCE_GROUP -w $WORKSPACE --query version)
}
finally {
    $next_model_version = [int] $latest_model_version + 1
}


## LOCAL CONTAINER BUILD FOR TESTING
$azureml_model_dir = "/var/azureml-app/azureml-models/$CONTAINER_MODEL_NAME/$next_model_version/models"

# -- locally build the docker image
(Get-Content -Path Dockerfile.template) -replace "#PATH_TO_PLUMBER_R#", `
    """$azureml_model_dir/plumber.R""" `
    | Set-Content -Path Dockerfile.temp
docker build -f Dockerfile.temp -t $image_tag .
Remove-Item Dockerfile.temp

# -- start the image locally
# note: if the image does not start, checking the logs of the container might help.
#       to see the log run "docker logs --tail 1000 <container id>" or simply use "View Logs" in VS.Code ;-)

& {docker rm -f -v $APP_NAME} -ErrorAction SilentlyContinue
docker run -d -p 8000:8000 -v ($LOCAL_CONTAINER_MODEL_PATH + ":$azureml_model_dir") `
    -e AZUREML_MODEL_DIR=$azureml_model_dir --name=$APP_NAME $image_tag

# -- test endpoints locally
# note: add --noproxy localhost to the following curl commands if you have configured proxies
curl "http://localhost:8000/live"
curl "http://localhost:8000/ready"
curl -H "Content-Type: application/json" --data "@sample_request.json" http://localhost:8000/score


## DEPLOY TO AZURE

# -- deploy model(s)
az ml model create --name $CONTAINER_MODEL_NAME --version $next_model_version --local-path $LOCAL_CONTAINER_MODEL_PATH `
    -g $RESOURCE_GROUP -w $WORKSPACE

# -- publish image to ACR
az acr login --name $acr_name
docker push $image_tag

# -- deploy endpoint to AML managed online endpoint
$endpoint_exists = [System.Convert]::ToBoolean(
    $(az ml endpoint show -n $UNIQUE_ENDPOINT_NAME --query name -o tsv -g $RESOURCE_GROUP -w $WORKSPACE) `
        -eq $UNIQUE_ENDPOINT_NAME
)
if ($endpoint_exists -eq $false) {
    az ml endpoint create -f endpoint.yml -n $UNIQUE_ENDPOINT_NAME `
        --set deployments[0].model.version=$next_model_version `
        --set deployments[0].environment.docker.image=$image_tag `
        -g $RESOURCE_GROUP -w $WORKSPACE
} else {
    az ml endpoint update -f endpoint.yml -n $UNIQUE_ENDPOINT_NAME `
        --set deployments[0].model.version=$next_model_version `
        --set deployments[0].environment.docker.image=$image_tag `
        -g $RESOURCE_GROUP -w $WORKSPACE
}

# -- check logs in case the deployment has failed
# az ml endpoint get-logs --name $UNIQUE_ENDPOINT_NAME --deployment default --lines 100 --resource-group $RESOURCE_GROUP --workspace-name $WORKSPACE

# -- get credentials for endpoint
# note: credentials expire when aml_token authentication is used
az ml endpoint get-credentials -n $UNIQUE_ENDPOINT_NAME -g $RESOURCE_GROUP -w $WORKSPACE

# -- now use Postman or similar to check if the endpoint works.
# if you are missing the endpoint URL for your model, check at ml.azure.com under Endpoints.


## CLEANUP

# -- delete endpoint and model in Azure
# az ml endpoint delete --name $UNIQUE_ENDPOINT_NAME -g $RESOURCE_GROUP -w $WORKSPACE
# az ml model delete --name model_a --version 2 -g $RESOURCE_GROUP -w $WORKSPACE
# TODO: delete image from ACR

# -- remove artifacts from local docker
# docker rm -f -v $APP_NAME
# docker image rm -f $APP_NAME