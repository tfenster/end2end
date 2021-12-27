---
layout: post
title: "Deploying Business Central in an Azure Container Instance using Bicep"
permalink: deploying-business-central-in-an-azure-container-instance-using-bicep
date: 2021-12-27 21:50:58
comments: false
description: "Deploying Business Central in an Azure Container Instance using Bicep"
keywords: ""
image: /images/arm-bicep-bc.png
categories:

tags:

---

More than four years ago, I [blogged about the usage of Azure Container Instances][aci-old] for Business Central (well, NAV at that time) including an [Azure Quickstart Template][quickstart] and I wanted to update that for quite some time for three reasons: 

- Business Central works for a while now using artifacts on top of a generic image and I have adjusted the quickstart template, but never blogged about it [^1]
- Microsoft has realized that [ARM templates][arm] really had disadvantages, especially when it came to maintenance and improvement of your templates, and they fortunately came up with [Bicep][bicep], a much leaner and cleaner approach to Azure IaC (Infrastructure as Code). I played around with it, but never really used it, so updating my quickstart template seemed like a good project for it
- As I learned when creating another quickstart template (a [Windows Docker Host with Portainer and Traefik pre-installed][other-quickstart] [^2]), you can optimize the GUI when showing those quickstart templates in the Azure Portal and I wanted to use that for the BC template as well

## The TL;DR

If you want to just give it a try, do this: 

1. Click [here][quickstart-fork] [^3] and fill in the required fields. 
2. Skip the "Advanced configuration settings" and just hit "Review + create". 
3. When the validation has successfully finished, click on "Create". Now you will have to wait for a while but after something between 10 and 15 minutes, you should see "Your deployment is complete"
4. Click on deployment details and the single resource that was created, which is the container instance. There go to "Settings" -> "Containers" and select the "Logs" tab. Wait until you see "Ready for connections!" which shows that BC is ready
5. Copy the URL after "Web Client" in the log, go there and enter the username and password specified in step 1. With that, you should be logged in and ready to use Business Central!

To show you what it looks like, I have created this walkthrough video:

<video width="100%" controls>
  <source type="video/mp4" src="/images/bc-aci-walkthrough.mp4">
</video>

I hope it is obvious to anyone who has taken even a short look at it, but just to be clear: This is in no way a possible replacement for the [COSMO Azure DevOps & Docker Self-Service][d2s2]. As the name already says, that service covers a LOT more ground including but not limited to Azure DevOps, project and pipeline templates, VS Code integration and a Power App fronted, just to name a few. So while I think there are relevant scenarios where an ACI might help, please also don't get those two things confused.

## The details: Conversion from ARM to Bicep and UI definition

The conversion from ARM to Bicep was extremely easy, a pleasant surprise. All I needed to do was to "decompile" my existing ARM template, as explained [here][decompile]. The documentation explicitly warns that there is no guarantee, but for me, it worked perfectly. Granted, this was as easy an ARM template as possible, but still, that was nice. I had to clean up some minor things which the best practice analyzer in the Azure Quickstart Template repo warned about, but that took maybe five minutes in total. As a result, I now have a bicep file that looks like this:

{% highlight bicep linenos %}
@description('Name for the container group')
param contGroupName string = 'msdyn365bc'

@description('The DNS label for the public IP address. It must be lowercase. It should match the following regular expression, or it will raise an error: ^[a-z][a-z0-9-]{1,61}[a-z0-9]$')
@maxLength(50)
param dnsPrefix string

@description('The eMail address to be used when requesting a Let\'s Encrypt certificate')
param letsEncryptMail string

@description('Dynamics 365 Business Central Generic image (10.0.19041.985 is the version of Windows Server). See https://mcr.microsoft.com/v2/businesscentral/tags/list')
param bcRelease string = 'mcr.microsoft.com/businesscentral:10.0.19041.985'

@description('Dynamics 365 Business Central artifact URL. See https://freddysblog.com/2020/06/25/working-with-artifacts/ to understand how to find the right one.')
param bcArtifactUrl string = 'https://bcartifacts.azureedge.net/onprem/19.2.32968.33504/w1'

@description('Username for your BC super user')
param username string

@description('Password for your BC super user and your sa user on the database')
@secure()
param password string

@description('The number of CPU cores to allocate to the container')
param cpuCores int = 2

@description('The amount of memory to allocate to the container in gigabytes. Provide a minimum of 3 as he container will include SQL Server and BCST')
param memoryInGb int = 4

@description('Custom settings for the BCST')
param customNavSettings string = ''

@description('Custom settings for the Web Client')
param customWebSettings string = ''

@description('Change to \'Y\' to accept the end user license agreement available at https://go.microsoft.com/fwlink/?linkid=861843. This is necessary to successfully run the container')
@allowed([
  'Y'
  'N'
])
param acceptEula string = 'N'

@description('Please select the Azure container URL suffix for your current region. For the standard Azure cloud, this is azurecontainer.io')
@allowed([
  '.azurecontainer.io'
])
param azurecontainerSuffix string = '.azurecontainer.io'

@description('Default location for all resources.')
param location string = resourceGroup().location

@description('The base URI where artifacts required by this template are located including a trailing \'/\'')
param _artifactsLocation string = deployment().properties.templateLink.uri

@description('The sasToken required to access _artifactsLocation.  When the template is deployed using the accompanying scripts, a sasToken will be automatically generated. Use the defaultValue if the staging location is not secured.')
@secure()
param _artifactsLocationSasToken string = ''

var image = bcRelease
var publicdnsname = '${dnsPrefix}.${location}${azurecontainerSuffix}'
var foldersZipUri = uri(_artifactsLocation, 'scripts/SetupCertificate.zip${_artifactsLocationSasToken}')

resource contGroup 'Microsoft.ContainerInstance/containerGroups@2021-09-01' = {
  name: contGroupName
  location: location
  properties: {
    containers: [
      {
        name: contGroupName
        properties: {
          environmentVariables: [
            {
              name: 'ACCEPT_EULA'
              value: acceptEula
            }
            {
              name: 'accept_outdated'
              value: 'y'
            }
            {
              name: 'username'
              value: username
            }
            {
              name: 'password'
              value: password
            }
            {
              name: 'customNavSettings'
              value: customNavSettings
            }
            {
              name: 'customWebSettings'
              value: customWebSettings
            }
            {
              name: 'PublicDnsName'
              value: publicdnsname
            }
            {
              name: 'folders'
              value: 'c:\\run\\my=${foldersZipUri}'
            }
            {
              name: 'ContactEMailForLetsEncrypt'
              value: letsEncryptMail
            }
            {
              name: 'artifacturl'
              value: bcArtifactUrl
            }
            {
              name: 'certificatePfxPassword'
              value: password
            }
          ]
          image: image
          ports: [
            {
              protocol: 'TCP'
              port: 443
            }
            {
              protocol: 'TCP'
              port: 8080
            }
            {
              protocol: 'TCP'
              port: 7049
            }
            {
              protocol: 'TCP'
              port: 7048
            }
            {
              protocol: 'TCP'
              port: 80
            }
          ]
          resources: {
            requests: {
              cpu: cpuCores
              memoryInGB: memoryInGb
            }
          }
        }
      }
    ]
    restartPolicy: 'Never'
    osType: 'Windows'
    ipAddress: {
      type: 'Public'
      ports: [
        {
          protocol: 'TCP'
          port: 443
        }
        {
          protocol: 'TCP'
          port: 8080
        }
        {
          protocol: 'TCP'
          port: 7049
        }
        {
          protocol: 'TCP'
          port: 7048
        }
        {
          protocol: 'TCP'
          port: 80
        }
      ]
      dnsNameLabel: dnsPrefix
    }
  }
}

output containerIPAddressFqdn string = contGroup.properties.ipAddress.fqdn
{% endhighlight %}

While this might still look like a lot, I think it is trimmed down to the necessary information. If you compare that to an equivalent ARM template file, that will have many more lines, and more importantly, much more boilerplate code and clutter. So I really like how easily readable and understandable it is, if you have a rough idea of Azure Container Instances. If not, [this][aci-docs] should give you a good introduction. If you want a better understanding of Bicep, I would recommend the documentation mentioned above, but just a few things to point out:

- Lines 1-57 define the parameters for the template with types, default values and descriptions
- Lines 59-61 define variables for easier usage later
- From line 63 on the container group and then from line 68 on the container itself are defined with env variables (lines 71-116), image (line 117), ports (lines 118-139) and the requested virtual hardware (lines 140-145)
- Lines 149 and 150 define that the container should never restart on failure, and we want Windows as host OS
- Lines 151 to 176 then have the network configuration, again with the ports (lines 153-174) and now with the DNS name label in line 175
- Line 180 in the end show how you can define an output for the deployment

All of this is in my opinion very easy to understand, write and most importantly, maintain, which makes it a great progress compared to ARM templates.

If we were to just bring this into the Azure Portal, we would always show settings like the generic image or custom BCST settings, that probably only very few people would want to tinker with. On top of that, we would also show parameters that are only implementation details like the `_artifactsLocation` or the `_artifactsLocationSasToken`. In order to fix that, I created a UI definition file as explained [here][uidef]. That file looks more like an ARM template, so I want to only give you the [link][uidef.json] and make you aware that you can use it to provide multiple steps, define required and optional inputs, have complex inputs like passwords with confirmation, regex-based validation, custom validation error messages and more. So if you are looking for a tailored UI when providing a Bicep or ARM template for the Azure Portal, then this is a great way to get more influence over the actual rendering and user experience. There even is a [sandbox][sandbox] to make it easier to create those files.

I hope this gave you an idea what especially Bicep and also UI definitions are about. And if you maybe need a BC container, accessible from the internet and without any infrastructure or server setup, the Azure Quickstart Template might also be worth a try.

[aci-old]: https://www.axians-infoma.de/techblog/use-azure-container-instances-nav/
[quickstart]: https://azure.microsoft.com/en-us/resources/templates/?term=bc
[arm]: https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/
[bicep]: https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/
[other-quickstart]: https://azure.microsoft.com/en-us/resources/templates/docker-portainer-traefik-windows-vm/
[quickstart-fork]: https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Ftfenster%2Fazure-quickstart-templates%2Fpatch-1%2Fdemos%2Faci-bc%2Fazuredeploy.json/createUIDefinitionUri/https%3A%2F%2Fraw.githubusercontent.com%2Ftfenster%2Fazure-quickstart-templates%2Fpatch-1%2Fdemos%2Faci-bc%2FcreateUiDefinition.json
[pr]: https://github.com/Azure/azure-quickstart-templates/pull/12095
[decompile]: https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/decompile?tabs=azure-cli
[aci-docs]: https://docs.microsoft.com/en-us/azure/container-instances/container-instances-overview
[uidef]: https://docs.microsoft.com/en-us/azure/azure-resource-manager/managed-applications/create-uidefinition-overview
[d2s2]: https://marketplace.cosmoconsult.com/product/?id=345E2CCC-C480-4DB3-9309-3FCD4065CED4#view-overview
[uidef.json]: https://github.com/tfenster/azure-quickstart-templates/blob/7a77a238910d84a8a9e4aba6fab4345747a1944a/demos/aci-bc/createUiDefinition.json
[sandbox]: https://docs.microsoft.com/en-us/azure/azure-resource-manager/managed-applications/test-createuidefinition

[^1]: I actually thought I had, but I can't find it, so it seems like I didn't... :D
[^2]: Another topic I was quite sure I had blogged about, but can't find it as well. Either I am seriously struggling with internet research or my blogging backlog is longer than I thought.
[^3]: This is in my own fork for now, as I have a [PR][pr] for the Azure Quickstart Template library open, but not yet merged. That means that this link very likely will change in the future.