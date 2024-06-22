---
layout: post
title: "Set up certificates for Azure Key Vault access during development"
permalink: set-up-certificates-for-azure-key-vault-access-during-development
date: 2024-06-22 13:36:02
comments: false
description: "Set up certificates for Azure Key Vault access during development"
keywords: ""
image: /images/dotnet-keyvault.png
categories:

tags:

---

I am a big fan of trying to be as close to production even during development as possible. Therefore, if my .NET application needs a connection to an Azure Key Vault in production e.g. for secrets, I want to use that setup during development as well, even if the secret manager in the dotnet CLI would be a reasonable alternative as well. Microsoft provides a [documentation][doc] on how to set up certificate-based authentication for that scenario, but it is a step-by-step manual. I would prefer to be able to at least semi-automate it. Here is how you can use two small scripts to set it up:

## The TL;DR

For the following steps, I'll assume that you are developing in a [dev container][devcontainer] or [GitHub Codespace][ghcs]. We will create a certificate, set up an Azure Key Vault (inside a Resource Group) and set up an App Registration with that certification which will be used to access the Key Vault

- First, install the dotnet certificate tool with `dotnet tool install --global dotnet-certificate-tool`
- Then, download [createCert.sh][cc] and run it as `source createCert.sh`, which will create a self-signed certificate and store it with the cert tool
- Download [setupAndLogin.sh][sl], change the `tenant` and `subsc` variables to your tenant and subscription and then run that script as `source setupAndLogin.sh`, which will log you in to Azure and create a Resource Group
- Download [createAzInfra.sh][ca], potentially change the secrets to be set in the Key Vault and run it as `source createAzInfra.sh`. It will create the Key Vault, the App Registration and set everything up as required. It will also print out the required settings for your `appsettings.json`, so you can get started right away.
- Once you have done that, you can use a snippet like the following to set up the configuration provider that fetches the information from the Key Vault:
{% highlight csharp linenos %}
using var x509Store = new X509Store(StoreLocation.CurrentUser);

x509Store.Open(OpenFlags.ReadOnly);

var x509Certificate = x509Store.Certificates
    .Find(
        X509FindType.FindByThumbprint,
        builder.Configuration["AzureADCertThumbprint"] ?? "",
        validOnly: false)
    .OfType<X509Certificate2>()
    .Single();

builder.Configuration.AddAzureKeyVault(
    new Uri($"https://{builder.Configuration["KeyVaultName"]}.vault.azure.net/"),
    new ClientCertificateCredential(
        builder.Configuration["AzureADDirectoryId"],
        builder.Configuration["AzureADApplicationId"],
        x509Certificate));
{% endhighlight %}
- To access the information in the Key Vault, you can use something like the following snippet to get the content of a secret called `OpenWeatherApiKey`:
{% highlight csharp linenos %}
var openWeatherApiKey = _configuration.GetValue<string>("OpenWeatherApiKey");
{% endhighlight %}

## The details: Creating the certificate

The `createCert.sh` script looks like this:

{% highlight shell linenos %}
#! /bin/bash

openssl req -x509 -newkey rsa:4096 -keyout myKey.pem -out cert.crt -days 365 -noenc
openssl pkcs12 -export -out keyStore.pfx -inkey myKey.pem -in cert.crt
certificate-tool add --file ./keyStore.pfx
{% endhighlight %}

With lines 3 and 4, a new PKCS#12 archive cert is created and exported. The fifth line uses the cert tool to install the new cert and make it available later.

## The details: Login and base setup

The `setupAndLogin.sh` script has the following content:

{% highlight shell linenos %}
#! /bin/bash

let "randomIdentifier=$RANDOM*$RANDOM"
loc="westeurope"
rg="bc-techdays-chaos-$randomIdentifier"
tenant="539f23a3-6819-457e-bd87-7835f4122217" # ars solvendi
subsc="94670b10-08d0-4d17-bcfe-e01f701be9ff" # az sponsorship

az config set core.login_experience_v2=off 
az login --tenant $tenant
az account set --subscription $subsc
az group create --name $rg --location $loc

echo "cleanup:"
echo "az group delete -n $rg --no-wait"
{% endhighlight %}

Lines 3-5 generates a random identifier to avoid naming conflicts, the location to use and the name of the Resource Group. Then, lines 6 and 7 define the tenant and subscription to be used, in both cases using the respective GUIDs. Line 9 disables the new interactive login experience, line 10 logs in, lin 11 sets the subscription and line 12 creates the Resource Group. Lines 14 and 15 in the end print a command to delete the whole Resource Group, which you can use to clean up in the end.

## The details: Azure components

The last script `createAzInfra.sh`, has the following content:

{% highlight shell linenos %}
#! /bin/bash

kv="kv-bct-$randomIdentifier"

az keyvault create --name $kv --resource-group $rg --location $loc --enable-rbac-authorization false
az keyvault secret set --vault-name $kv --name "OpenWeatherCity" --value "Antwerp,be"
az keyvault secret set --vault-name $kv --name "OpenWeatherApiKey" --value "<tbd>"

app_create=$(az ad app create --display-name $rg)
app_id=$(echo $app_create | jq -r .id)
app_appid=$(echo $app_create | jq -r .appId)
az ad app credential reset --id $app_id --cert @cert.crt
thumbprint=$(az ad app credential list --id $app_id --cert | jq -r .[0].customKeyIdentifier)

sp_create=$(az ad sp create --id $app_appid)
sp_id=$(echo $sp_create | jq -r .id)
az keyvault set-policy --name $kv --object-id $sp_id --secret-permissions get list


echo "appsettings.json:"
echo "\"KeyVaultName\": \"$kv\","
echo "\"AzureADApplicationId\": \"$app_appid\","
echo "\"AzureADCertThumbprint\": \"$thumbprint\","
echo "\"AzureADDirectoryId\": \"$tenant\""

echo "cleanup:"
echo "az ad app delete --id $app_id"
{% endhighlight %}


Line 3 generates a name for the Key Vault, incorporating the random identifier created previously to circumvent potential naming conflicts. Line 5 creates the Key Vault itself, while lines 6 and 7 create two secrets with values within the Key Vault. Line 9 creates an App Registration. Lines 10 and 11 parse the output of line 9 to extract the ID and the App ID of the App Registration. Line 12 employs the certificate generated in the preceding script to attach it to the App Registration. Line 13 retrieves the thumbprint of the certificate for future use. Line 15 creates a Service Principal for the App Registration, and line 16 obtains the ID of that Service Principal. Finally, line 17 grants the Service Principal the requisite permissions on the key vault. Lines 20-24 provide instructions for implementing the necessary settings in a .NET application, while lines 26 and 27 offer a command to delete the app registration for cleanup purposes. 

This approach can serve as a foundation for developing a .NET application with access to a Key Vault that employs the same mechanism during development, as an alternative to utilizing the .NET secret manager.

[doc]: https://learn.microsoft.com/en-us/aspnet/core/security/key-vault-configuration?view=aspnetcore-8.0#use-application-id-and-x509-certificate-for-non-azure-hosted-apps
[cc]: https://github.com/tfenster/presentation-src/blob/cb3a7c87ab14af882b9aa21c9d4e6279a9df2dcc/createCert.sh
[devcontainer]: https://code.visualstudio.com/docs/devcontainers/containers
[ghcs]: https://docs.github.com/en/codespaces/overview
[sl]: https://github.com/tfenster/presentation-src/blob/cb3a7c87ab14af882b9aa21c9d4e6279a9df2dcc/setupAndLogin.sh
[ca]: https://github.com/tfenster/presentation-src/blob/cb3a7c87ab14af882b9aa21c9d4e6279a9df2dcc/createAzInfra.sh