# -- configuration
$ErrorActionPreference = "Stop"

$RESOURCE_GROUP="AzureMLSpikesAndDemos"
$WORKSPACE="AzureMLSpikesAndDemos"
$APP_NAME="r-on-aml-moe"  # at some places, r-on-aml-moe is still hard-coded due to complexity, needs to be made dynamic
$UNIQUE_ENDPOINT_NAME="r-on-aml-moe-fglp9dk4"  # ensure that this is unique

$ACR_NAME=$(az ml workspace show -g $RESOURCE_GROUP -w $WORKSPACE --query container_registry -o tsv).split("/")[-1]
$IMAGE_TAG="$ACR_NAME.azurecr.io/$APP_NAME" + ":latest"

# ask the local docker instance to build the image
docker build -t $IMAGE_TAG .

# start the image locally
docker rm -f -v $APP_NAME | Out-Null
docker run --rm -d -p 8000:8000 -v "$PWD/scripts:/var/azureml-app/azureml-models/r-on-aml-moe/1/scripts" --name=$APP_NAME $IMAGE_TAG

# test endpoints
curl "http://localhost:8000/live"
curl "http://localhost:8000/ready"
curl -H "Content-Type: application/json" --data "@sample_request.json" http://localhost:8000/score

# publish image to ACR
az acr login --name $ACR_NAME
docker push $IMAGE_TAG

# deploy endpoint to AML managed online endpoint
$endpoint_exists = [System.Convert]::ToBoolean(
    $(az ml endpoint show -n $UNIQUE_ENDPOINT_NAME --query name -o tsv -g $RESOURCE_GROUP -w $WORKSPACE | Out-Null) -eq $UNIQUE_ENDPOINT_NAME
)
if ($endpoint_exists -eq $false) {
    az ml endpoint create -f endpoint.yml -n $UNIQUE_ENDPOINT_NAME -g $RESOURCE_GROUP -w $WORKSPACE
} else {
    az ml endpoint update -f endpoint.yml -n $UNIQUE_ENDPOINT_NAME -g $RESOURCE_GROUP -w $WORKSPACE
}

# check logs in case the deployment has failed
# az ml endpoint get-logs --name $UNIQUE_ENDPOINT_NAME --deployment default --lines 100 --resource-group $RESOURCE_GROUP --workspace-name $WORKSPACE

# get credentials for endpoint
# note: credentials expire when aml_token authentication is used
az ml endpoint get-credentials -n $UNIQUE_ENDPOINT_NAME -g $RESOURCE_GROUP -w $WORKSPACE

# now use Postman or similar to check if the endpoint works.
# if you are missing the endpoint URL for your model, check at ml.azure.com under Endpoints.
