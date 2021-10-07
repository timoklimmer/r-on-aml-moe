# Deploying an R web service to Azure the easy way

This is an example for deploying an R-based inferencing web service to an
[Azure Machine Learning Managed Online Endpoint](https://docs.microsoft.com/en-us/azure/machine-learning/concept-endpoints).
It has been inspired by an example from the Azure Machine Learning team [here](https://github.com/Azure/azureml-examples/tree/main/cli/endpoints/online/custom-container/r). You can use this repo to directly deploy to Azure from RStudio.

In case you are interested, I have written a companion article on Medium [here](https://medium.com/@timo.klimmer/azure-mls-managed-online-endpoints-rock-cbd021c80263).

## Prerequisites

To run the code, you need
- this repository cloned or downloaded to your local machine
- optional: [RStudio](https://www.rstudio.com) for editing/running R scripts
- [PowerShell Core](https://github.com/powershell/powershell), runs on Windows, Linux and Mac
- Docker running locally (not required when using a
  [Compute Instance](https://docs.microsoft.com/en-us/azure/machine-learning/concept-compute-instance) or
  [Data Science Virtual Machine (DSVM)](https://aka.ms/dsvm) because Docker is pre-installed there already)
- an Azure Machine Learning workspace incl. sufficient permissions
- an [Azure CLI](https://docs.microsoft.com/en-us/cli/azure)
- version 2 of AML's CLI extension installed, for details see
  [here](https://docs.microsoft.com/en-us/azure/machine-learning/how-to-configure-cli).

## How to use this

1. Install all required prerequisites (see above).
2. Adjust the code/files in folder `model-training` to your needs using the editor of your choice. You can do everything
   you want/need to in that folder. Only requirement is that you save your final model(s)/files in the `webservice`
   folder after training completion.

   > Tip: If your local machine is too slow for training the model, try the RStudio pre-installed in an [Azure Machine
   > Learning Compute Instance](https://docs.microsoft.com/en-us/azure/machine-learning/concept-compute-instance) or a
   > [Data Science Virtual Machine (DSVM)](https://aka.ms/dsvm). With the hardware power provided there, you can train
   > your models much faster. For an overview of available machine sizes in Azure, see
   > [here](https://docs.microsoft.com/en-us/azure/virtual-machines/sizes).

3. Edit the `webservice/plumber.R` file to fit to your needs. If you use RStudio, you can directly test your plumber
   script from there.
4. Edit the `sample_request.json` file and give it an example JSON document that is passed to your web service for
   testing.
5. Modify the `Dockerfile.template` file as needed. For example, you may need to edit this file for installing
   additional R packages.
6. Edit the `config.psd1` file and update its settings as needed.
7. Open a PowerShell Core terminal and navigate to this folder. If you are using RStudio, you can use a terminal
   directly in RStudio.
8. Run the `deploy.ps1` script (from the directory where it is located). The script will then:
   * Ask you to confirm your configuration settings.
   * Build and start a local Docker image which contains your web service.
   * Ask you if you want to deploy the image to an Azure Machine Learning Managed Online Endpoint.
   * If yes, deploy the model and the container.
   * Show web service URI (and password if comment in code is removed).
   * Run another test. This time against the web service in Azure.
   * By passing a `-AcceptConfiguration` and/or `-DeployToAzure` switch, you can bypass the user confirmations.

> Note: you can configure RStudio to use PowerShell in its terminal. That way, you can deploy your web service entirely
>       from RStudio.

## Troubleshooting

### PowerShell does not run the deploy.ps1 script and writes something about an execution policy.

By default, PowerShell runs only signed scripts. To run the provided script, you may need to re-configure PowerShell
first. This is a one-time action.

Quick fix: Run `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned` in PowerShell (requires admin privileges).

More details about execution policies can be found [here](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-7.1)

## Documentation

For details on Azure Machine Learning, see the documentation
[here](https://docs.microsoft.com/en-us/azure/machine-learning).

## Disclaimer
As always, everything provided here is provided "as is". Feel free to use but don't blame me if things go wrong.

I am open for pull requests. Please submit a pull request before starting your own public fork so we can keep things
together.