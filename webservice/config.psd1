<#
Stores several configuration settings.

Notes: - If you need additional packages or other adjustments of the container image, edit the Dockerfile.template.

       - Intentionally not using YAML or JSON here as those formats either don't support comments or are not well
         supported in PowerShell. Could/should be modified to YAML or JSON once support has improved.
#>

@{
    # name of the app you are publishing
    APP_NAME = "r-on-aml-moe"

    # unique endpoint name, has to be unique because it will be part of the web service address later
    # PLEASE change this value to avoid naming collisions with others
    UNIQUE_ENDPOINT_NAME = "r-on-aml-moe-tr3p5dm6"

    # name of your model
    MODEL_NAME = "r-on-aml-moe"

    # Azure subscription ID, leave empty to use your default Azure subscription
    AZURE_SUBSCRIPTION_ID = ""

    # the resource group in Azure where the Azure Machine Learning workspace lives
    RESOURCE_GROUP = "AzureMLSpikesAndDemos"
    
    # name of the Azure Machine Learning workspace
    WORKSPACE = "AzureMLSpikesAndDemos"   

    # virtual machine(s) size
    INSTANCE_TYPE = "Standard_F2s_v2"

    # number of virtual machines serving the requests against the webservice
    INSTANCE_COUNT = 1

    # whether to enable app insights or not
    APP_INSIGHTS_ENABLED = $True

    # proxy addresses
    # note: Docker needs to be configured separately for proxy usage
    # HTTP proxy address (in case you need the HTTP_PROXY variable set, else use an empty string)
    HTTP_PROXY = ""
    
    # HTTPS proxy address (in case you need the HTTPS_PROXY variable set, else use an empty string)
    HTTPS_PROXY = ""
}