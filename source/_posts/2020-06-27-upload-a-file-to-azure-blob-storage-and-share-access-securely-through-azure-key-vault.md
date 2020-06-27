---
layout: post
title: "Upload a file to Azure Blob Storage and share access securely through Azure Key Vault"
permalink: upload-a-file-to-azure-blob-storage-and-share-access-securely-through-azure-key-vault
date: 2020-06-27 21:34:07
comments: false
description: "Upload a file to Azure Blob Storage and share access securely through Azure Key Vault"
keywords: ""
categories:
image: /images/keyvault-and-storage.png

tags:

---

Did you ever have the need to store a file "somewhere in the cloud" and give someone or something access without the possibility to enter account information or similar means to authenticate? I know there are services out there who provide that, but what if you also need a secure way to share the link, e.g. with everyone in your company. With the combination of [Azure KeyVault][keyvault] and [Azure Blob Storage][blob], you can achieve exactly that. And because I get bored quickly if I have to do the same thing more than a very small number of times[^1], I have automated the process.

## The TL;DR
The idea is to upload the file to an Azure Blob Storage container (something in the cloud similar to a folder on your local file system) and generate a URL to it with a secret, called a [shared access signature][sas] (SAS). That URL can be used to download the file without a need for further authentication. The URL in turn is stored as [secret][secret] in an Azure Key Vault. You can then allow e.g. everyone in your Azure tenant read access to that secret, so they can read it and use the URL to get to the file. My [little helper tool][github] reads a Dynamics 365 Business Central license file, creates a meaningful id, uploads it and stores the secret URL in a Key Vault.

## The details
For those not familiar with Dynamics 365 Business Central license files: Those files usually are stored with the extension .flf and have a clear text header which among others has the country, version and expiration date. Therefore, my tool first reads all .flf files in a given folder and extracts that information. It also creates an abbreviation using the version and country because I want to store one license for each combination of country and version and refer to that later:

{% highlight csharp linenos %}
var flfs = Directory.GetFiles(path, "*.flf");
var licensesWithFile = new Dictionary<string, License>();
foreach (var flf in flfs)
{
    Console.WriteLine($"\nWorking on file {flf}");
    var lines = File.ReadAllLines(flf);
    var foundCountry = false;
    var foundVersion = false;
    var foundExpirationDate = false;
    var license = new License();
    license.FlfPath = flf;
    for (int i = 0; (i < lines.Length && !(foundCountry && foundVersion && foundExpirationDate)); i++)
    {
        var line = lines[i];
        if (DEBUG) Console.WriteLine($"\tWorking on line {line}");
        if (line.StartsWith("Country                 : ") || line.StartsWith("Land                    : "))
        {
            license.Country = line.Substring(26);
            Console.WriteLine($"\tFound country {license.Country}");
            if (COUNTRIES.ContainsKey(license.Country))
                foundCountry = true;
            else
                Console.WriteLine($"\tUnknown country");
        }
        else if (line.StartsWith("Product Version	        : ") || line.StartsWithrsion	        : "))
        {
            license.Version = line.Substring(26);
            Console.WriteLine($"\tFound version {license.Version}");
            if (VERSIONS.ContainsKey(license.Version))
                foundVersion = true;
            else
                Console.WriteLine($"\tUnknown version");
        }
        else if (line.StartsWith("Expires                 : "))
        {
            license.ExpirationDate = DateTime.Parse(line.Substring(26), new CultureInfo("en-us"));
            Console.WriteLine($"\tFound date {license.ExpirationDate.ToShortDateString()}");
            foundExpirationDate = true;
        }
        else if (line.StartsWith("Abl.Dtm.                : "))
        {
            license.ExpirationDate = DateTime.Parse(line.Substring(26), new CultureInfo("de-de"));
            Console.WriteLine($"\tFound date {license.ExpirationDate.ToShortDateString()}");
            foundExpirationDate = true;
        }
    }
    if (!foundCountry || !foundVersion || !foundExpirationDate)
    {
        Console.WriteLine("\tEither version, country or expiration date is missing!");
    }
    else
    {
        license.Abbreviation = $"devlic-{VERSIONS[license.Version]}{license.Version}-{COUNTRIES[license.        Console.WriteLine($"\tIdentified abbreviation {license.Abbreviation}");
        licensesWithFile.Add(license.Abbreviation, license);
    }
}
{% endhighlight %}

The next step is to authenticate to Azure, in my case most conveniently by using an interactive browser credential, and to get clients to the Blob service, to the Blob container and the Key Vault:

{% highlight csharp linenos %}
var accountUrl = $"https://{storageAccountName}.blob.core.windows.net";
var blobServiceClient = new BlobServiceClient(new Uri(accountUrl), cred);
var userDelegationKey = blobServiceClient.GetUserDelegationKey(DateTimeOffset.UtcNow, DateTimeOffset.UtcNow.AddMinutes(60));
var blobContainerClient = blobServiceClient.GetBlobContainerClient(containerName);
var keyVaultClient = new SecretClient(new Uri($"https://{keyVaultName}.vault.azure.net"), cred);
{% endhighlight %}

With those, it's easy to upload the file and create a URL including the SAS token, in my case only with read permissionand valid until the license expires[^2]:

{% highlight csharp linenos %}
foreach (var abbreviation in licensesWithFile.Keys)
{
    var license = licensesWithFile[abbreviation];
    var blobClient = blobContainerClient.GetBlobClient(abbreviation);
    var blobContentInfo = blobClient.Upload(license.FlfPath, true);
    var blobSasBuilder = new BlobSasBuilder
    {
        StartsOn = DateTime.UtcNow,
        ExpiresOn = license.ExpirationDate.AddDays(1),
        BlobContainerName = containerName,
        BlobName = abbreviation,
    };
    blobSasBuilder.SetPermissions(BlobSasPermissions.Read);
    var sasToken = blobSasBuilder.ToSasQueryParameters(userDelegationKey, storageAccountName).ToString();
    var sasUrl = $"{accountUrl}/{containerName}/{abbreviation}?{sasToken}";
{% endhighlight %}

The last step is to store that URL in a secret and set the expiration date:

{% highlight csharp linenos %}
    var secretResponse = keyVaultClient.SetSecret(abbreviation, sasUrl);
    var props = new SecretProperties(secretResponse.Value.Id);
    props.ExpiresOn = license.ExpirationDate.AddDays(1);
    keyVaultClient.UpdateSecretProperties(props);
}
{% endhighlight %}

As you can see, it actually is not such a big deal, but with the number of licenses we handle and how quickly they expire, this is a real time-safer and might be for you as well, if you have a similar scenario.

[^1]: Ideally 1
[^2]: Depending on your scenario, especially how much you want to protect that file, the expiration date could be very short

[keyvault]: https://azure.microsoft.com/en-us/services/key-vault/
[blob]: https://azure.microsoft.com/en-us/services/storage/blobs/
[sas]: https://docs.microsoft.com/en-us/azure/storage/blobs/storage-blob-user-delegation-sas-create-dotnet
[secret]: https://docs.microsoft.com/en-us/azure/key-vault/secrets/about-secrets
[github]: https://github.com/cosmoconsult/azstorage-for-bc-licenses