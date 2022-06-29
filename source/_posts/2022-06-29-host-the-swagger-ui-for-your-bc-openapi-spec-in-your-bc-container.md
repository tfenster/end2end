---
layout: post
title: "Host the Swagger UI for your BC OpenAPI spec in your BC container"
permalink: host-the-swagger-ui-for-your-bc-openapi-spec-in-your-bc-container
date: 2022-06-29 15:59:02
comments: false
description: "Host the Swagger UI for your BC OpenAPI spec in your BC container"
keywords: ""
image: /images/swagger openapi bc.png
categories:

tags:

---

Business Central has become a pretty open ERP system with maybe not a great, but certainly a fair [API][api], that can be used to integrate with 3rd party applications or create what Microsoft calls ["Connect Apps"][connect-apps]. You can also create your own ["Custom APIs"][custom-apis], which allows for even more integration scenarios to be covered. But how do you let a developer know, how that API works, which entities and actions are available etc.? Since a couple of releases, we can [create an Entity Data Model XML (".edmx") file][obtain-edmx] from Business Central, which in turn can be converted into an [OpenAPI specification][openapi-spec] file and then be presented using [Swagger UI][swagger-ui]. With that, we get a nice-looking, easy to use description of the standard or custom API, which should get every developer a great starting point:

![screeenshot of swagger ui](/images/swaggerui.png)
{: .centered}

But wouldn't it be nice, if we wouldn't have to run some scripts, but instead get it directly when starting a BC container? Thanks to [Waldo][waldo] - btw. also a good link to get a bit more information on the topic - and the override mechanism in the BC container scripts, we can easily do that!

## The TL;DR

If you create a BC container like this

```
New-BcContainer -accept_outdated -accept_eula -containerName test -imageName mybc `
-artifactUrl (Get-BCArtifactUrl -type Sandbox -country DE) -auth NavUserPassword -updateHosts `
-myscripts @("https://raw.githubusercontent.com/tfenster/nav-docker-samples/swaggerui/AdditionalSetup.ps1")
```

it will run an additional setup script during startup, which will create everything required to give you the Swagger UI for the BC API. If you go to http://test:3001 when the container has finished starting, then you will get the Swagger UI!

## The details

Most of this is built based on the blog post by [Waldo][waldo], the [accompanying scripts][waldo-scripts] and a [comment][erik] by Erik van Rijn. As a "delivery mechanism", I am using the custom scripts feature in bccontainerhelper to point at my script, as you can see in the `-myscripts` parameter above.

{% highlight powershell linenos %}
# invoke default
. (Join-Path $runPath $MyInvocation.MyCommand.Name)

if (-not("dummy" -as [type])) {
    add-type -TypeDefinition @"
using System;
using System.Net;
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;
public static class Dummy {
    public static bool ReturnTrue(object sender,
        X509Certificate certificate,
        X509Chain chain,
        SslPolicyErrors sslPolicyErrors) { return true; }
    public static RemoteCertificateValidationCallback GetDelegate() {
        return new RemoteCertificateValidationCallback(Dummy.ReturnTrue);
    }
}
"@
}

[System.Net.ServicePointManager]::ServerCertificateValidationCallback = [dummy]::GetDelegate()
# heavily inspired and with usage of https://github.com/waldo1001/BusinessCentralOpenAPIToolkit
try {
    # setup Waldo's Open API toolkit
    mkdir c:\openapi
    cd c:\openapi
    Invoke-WebRequest -Uri 'https://github.com/waldo1001/BusinessCentralOpenAPIToolkit/archive/refs/heads/main.zip' -UseBasicParsing -OutFile BusinessCentralOpenAPIToolkit.zip
    Expand-Archive .\BusinessCentralOpenAPIToolkit.zip -DestinationPath .
    cd .\BusinessCentralOpenAPIToolkit-main\
    remove-item -Recurse node_modules
    cd .\Microsoft.OpenApi.OData\
    Invoke-WebRequest -Uri 'https://www.nuget.org/api/v2/package/Microsoft.OpenApi.OData/1.0.8' -UseBasicParsing -OutFile Microsoft.OpenApi.OData.zip
    Expand-Archive .\Microsoft.OpenApi.OData.zip -DestinationPath .
    Move-Item .\lib\netstandard2.0\* . -Force
    cd ..

    # install choco, nodejs and express
    Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    refreshenv
    choco feature enable -n allowGlobalConfirmation
    choco install nodejs-lts
    refreshenv
    & 'C:\Program Files\nodejs\npm' install express swagger-ui-express yamljs

    # download data model
    $cred = New-Object System.Management.Automation.PSCredential($username, $securepassword)
    $BaseUrl = '$($protocol)localhost:7048/BC/api/v2.0'
    $Outfile = './MicrosoftAPIv2.0/MicrosoftAPIv2.0.edmx'
    $Metadataurl = $BaseUrl + '/$metadata?$schemaversion=2.0&tenant=default'
    Invoke-WebRequest -credential $cred -Uri $Metadataurl -OutFile $Outfile -UseBasicParsing

    # convert data model
    $folder = './MicrosoftAPIv2.0/'
    $Source = Get-ChildItem -Path $folder -Filter '*.edmx'
    $Dest = $folder + [io.path]::GetFileNameWithoutExtension($Source) + '.yaml'
    ./Microsoft.OpenApi.OData/OoasUtil.exe -y -i $Source.FullName -o $Dest 

    # start express with SwaggerUI frontend 
    start-job -ScriptBlock { cd 'C:\openapi\BusinessCentralOpenAPIToolkit-main'; & 'C:\Program Files\nodejs\node' .\MicrosoftAPIv2.0\MicrosoftAPIv2.0.js }
}
catch {
    "An error occurred that could not be resolved."
}
{% endhighlight %}

In lines 26 to 37, the script downloads and expands Waldo's toolkit and replaces the OpenApi.OData binaries from Microsoft with a package from NuGet as suggested by Erik. Lines 39-44 install chocolatey and then use chocolatey to install node.js. As we want to use [Express][express] as Web Server as suggested by Microsoft and Waldo, the script installs this and other packages in line 45. With that, we have the "infrastructure" in place and can take care of the model. First, the script downloads the data model (lines 47-52), then it converts it to the OpenAPI spec file (lines 54-58) and in the end starts the node.js script that uses express to host the Swagger UI frontend (line 61). Note that this last step is put into a `start-job` call, because `node` otherwise wouldn't return and block the container startup.

Overall, nothing very special or complicated, but I still think a nice setup to deliver a Swagger UI frontend directly with your BC container to any developer that wants to interact with standard or custom BC APIs.

[bc-openapi]: https://docs.microsoft.com/en-us/dynamics365/business-central/dev-itpro/api-reference/v2.0/dynamics-open-api
[api]: https://docs.microsoft.com/en-us/dynamics365/business-central/dev-itpro/api-reference/v2.0/
[connect-apps]: https://docs.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/devenv-develop-connect-apps
[custom-apis]: https://docs.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/devenv-develop-custom-api
[openapi-spec]: https://swagger.io/specification/
[obtain-edmx]: https://docs.microsoft.com/en-us/dynamics365/business-central/dev-itpro/webservices/return-obtain-service-metadata-edmx-document
[swagger-ui]: https://swagger.io/tools/swagger-ui/
[waldo]: https://www.waldo.be/2021/06/09/documenting-your-business-central-custom-apis-with-openapi-swagger/
[waldo-scripts]: https://github.com/waldo1001/BusinessCentralOpenAPIToolkit
[erik]: https://www.waldo.be/2021/06/09/documenting-your-business-central-custom-apis-with-openapi-swagger/#comment-36863
[express]: https://expressjs.com/