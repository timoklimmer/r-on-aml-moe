# R on Azure Machine Learning's Managed Online Endpoints

This is an example for running an R model in an Managed Online Endpoint.

The code has been inspired by an example from the Azure Machine Learning team
[here](https://github.com/Azure/azureml-examples/tree/main/cli/endpoints/online/custom-container/r).

To run the code, you need:
- an Azure Machine Learning workspace
- version 2 of AML's CLI extension installed, see
  [here](https://docs.microsoft.com/en-us/azure/machine-learning/how-to-configure-cli) for details.
- [PowerShell Core](https://github.com/powershell/powershell). (If you don't want or can't use PowerShell Core: The
  provided script can likely be ported to another scripting language of your choice.)
- Docker running locally

For details, Azure Machine Learning's documentation is located
[here](https://docs.microsoft.com/en-us/azure/machine-learning).

As always, provided "as is". Feel free to use but don't blame me if things go wrong.