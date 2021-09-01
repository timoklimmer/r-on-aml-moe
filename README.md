# R on Azure Machine Learning's Managed Online Endpoints

This is a quick example for running an R model in an Managed Online Endpoint.

The code has been inspired by an example from the Azure Machine Learning team
[here](https://github.com/Azure/azureml-examples/tree/main/cli/endpoints/online/custom-container/r).

To run the code, you need:
- an Azure Machine Learning workspace
- the v2 CLI installed, see [here](https://docs.microsoft.com/en-us/azure/machine-learning/how-to-configure-cli) for
  details.
- PowerShell, ideally [PowerShell Core](https://github.com/powershell/powershell). (If you don't want or can't use
PowerShell: The provided script can easily be ported to another scripting language.)
- Docker running locally

For details, Azure Machine Learning's documentation is located
[here](https://docs.microsoft.com/en-us/azure/machine-learning).

As always, provided "as is". Feel free to use but don't blame me if things go wrong.