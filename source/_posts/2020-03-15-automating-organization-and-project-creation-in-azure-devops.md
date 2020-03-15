---
layout: post
title: "Automating organization and project creation in Azure DevOps"
permalink: automating-organization-and-project-creation-in-azure-devops
date: 2020-03-15 22:45:40
comments: false
description: "Automating organization and project creation in Azure DevOps"
keywords: ""
categories:
image: /images/azdevops-automation.png

tags:

---

A lot of great content is available if you want to learn how to automate tasks with Azure DevOps, most often probably for Continuous Integration / Continuous Delivery (CI/CD) but also automated tests, creating environments or automated code quality assurance. It gets a bit thinner when you look into automating the setup of Azure DevOps itself but as so much official documentation created by Microsoft lately, the [Azure DevOps Services REST API Reference][DevOps-REST-API] is quite good. But if you want to do this from scratch, which means creating an Azure DevOps organization, you will have a hard time finding anything. But fortunately, it can be done.

## The TL;DR
Creating a DevOps organization is not possible via any of the publicly documented REST APIs of Azure DevOps itself, but you can use an [Azure Resource Manager][arm] (ARM) template. Querying all available organizations for you works by using the REST API. Once you have your organization in place, you can easily create a project by following the documented API calls as well.

## The details: Authorization (for testing)
Whatever you do when talking to the Azure DevOps REST API or other endpoints, you will need to authorize. There are [quite some options][auth-options] for that but if I just want to do some testing, I usually go to the [Azure DevOps / Visual Studio My Information][my-information] page, open the development tools of my browser and look for a request to `https://aex.dev.azure.com/_apis/User/User`. In the request headers the Bearer token is used and I just copy that to later use it in my own requests. 

![bearer](/images/azdevops-automation-bearer.png)
{: .centered}

Note that this token will expire after an hour, so you will have to renew it frequently.

## The details: Reading a list of your organizations and creating one
Now to the actual data requests: I assumed that reading a list of organizations my user would be easy. And indeed there is a [list of accounts][accounts-list] request documented, but if you call it, the response tells you that you need to add either an ownerId or memberId as param. 

{% highlight http linenos %}
GET https://app.vssps.visualstudio.com/_apis/accounts?&api-version=5.1
Authorization: Bearer ...

HTTP/1.1 400 Bad Request
...
{
  "$id": "1",
  "innerException": null,
  "message": "Necessary parameters ownerId or memberId were not provided in the request.",
  "typeName": "Microsoft.VisualStudio.Services.Account.AccountException, Microsoft.VisualStudio.Services.WebApi",
  "typeKey": "AccountException",
  "errorCode": 0,
  "eventId": 4236
}

{% endhighlight %}

To get the ID of your user, you call the [profiles service][profiles-service] like this (ID redacted):

{% highlight http linenos %}
GET https://app.vssps.visualstudio.com/_apis/profile/profiles/me?api-version=5.1
Authorization: Bearer ...

HTTP/1.1 200 OK
...
{
  "displayName": "Tobias Fenster",
  "publicAlias": "ee7df337-9c0e-677f-8012-cbd773bc1a83",
  "emailAddress": "tobias.fenster@cosmoconsult.com",
  "coreRevision": 307260222,
  "timeStamp": "2019-09-27T06:03:42.8633333+00:00",
  "id": "ee7df337-9coe-677f-8012-cbd773bc1a83",
  "revision": 307260222
}
{% endhighlight %}

If you take the ID from there and use that e.g. as memberId in the call to the account service, you get all organizations where you are a member:

{% highlight http linenos %}
GET https://app.vssps.visualstudio.com/_apis/accounts?memberId=ee7df337-9c0e-677f-8012-cbd773bc1a83&api-version=5.1
Authorization: Bearer ...

HTTP/1.1 200 OK
...
{
  "count": 10,
  "value": [
    {
      "accountId": "...",
      "accountUri": "https://vssps.dev.azure.com:443/cc-demo-devops/",
      "accountName": "cc-demo-devops",
      "properties": {}
    },
    {
      "accountId": "...",
      "accountUri": "https://vssps.dev.azure.com:443/cc-whatever/",
      "accountName": "cc-iERP",
      "properties": {}
    },
    ...
  ]
}
{% endhighlight %}

But what if you want to create a new one? As I wrote before, there doesn't seem to be a service in the Azure DevOps REST API that can do that, but you can use an ARM template. As you see when looking at the resource names that this capability seems to come from the days of good old Visual Studio Team Services. All you need to do is e.g. go to the Azure Portal, click on "Create a resource" and search for "template deployment". When you create that, you can select "Build your own template in the editor", paste the following into the editor and click "save":

{% highlight json linenos %}
{
    "$schema": "http://schema.management.azure.com/schemas/2014-04-01-preview/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "accountName": {
            "type": "String",
            "metadata": {
                "description": "The name of the Azure DevOps organization to be created."
            }
        }
    },
    "variables": {},
    "resources": [
        {
            "type": "Microsoft.VisualStudio/account",
            "apiVersion": "2014-02-26",
            "name": "[parameters('accountName')]",
            "location": "[resourceGroup().location]",
            "dependsOn": [],
            "tags": {},
            "properties": {
                "operationType": "Create",
                "accountName": "[parameters('accountName')]"
            },
            "resources": []
        }
    ]
}
{% endhighlight %}

Then you select an existing resource group or create a new one, enter the name of the new organization and click on purchase. After a couple of seconds, you will get a "deployment succeeded" message and while the resource group is still empty, you can go to `https://dev.azure.com/<your-new-org-name>` and find your new organization there. I named mine devops-test-tfe, so I can find it at `https://dev.azure.com/devops-test-tfe`. You will also get welcome mails in case you forgot that you created it...

While I would have hoped to stay within in the Azure DevOps REST APIs for all automation around Azure DevOps, this seems like a fair enough workaround to me and after some initial frustration after internet research that seemed to indicate that it actually isn't possible, I am quite happy to have found a way.

## The details: Creating a project
But an Azure DevOps organization without a project doesn't make too much sense, so let's go ahead and create one: This works very straight forward and exactly as documented in the ["Projects - Create"][projects-create] part of the Core Services documentation. All you need to do is supply the name of your project, select the version control technology you want to use (very likely Git these days) and the process template. I am a fan of the agile template (and not a fan of the SCRUM template), but again the [documentation][process-templates] should give you a good idea of what to use. Unfortunately while we can just use a readable variable value for the version control technology, we need to know the ID of the process template. We can get it by calling one more service, in that case the [processes part of the Core service][processes-service].

{% highlight http linenos %}
GET https://dev.azure.com/devops-test-tfe/_apis/process/processes?api-version=5.1
Authorization: Bearer ...

HTTP/1.1 200 OK
...
{
  "count": 4,
  "value": [
    {
      "id": "6b724908-ef14-45cf-84f8-768b5384da45",
      "description": "This template is for teams who follow the Scrum framework.",
      "isDefault": false,
      "type": "system",
      "url": "https://dev.azure.com/devops-test-tfe/_apis/process/processes/6b724908-ef14-45cf-84f8-768b5384da45",
      "name": "Scrum"
    },
    {
      "id": "b8a3a935-7e91-48b8-a94c-606d37c3e9f2",
      "description": "This template is flexible for any process and great for teams getting started with Azure DevOps.",
      "isDefault": true,
      "type": "system",
      "url": "https://dev.azure.com/devops-test-tfe/_apis/process/processes/b8a3a935-7e91-48b8-a94c-606d37c3e9f2",
      "name": "Basic"
    },
    {
      "id": "27450541-8e31-4150-9947-dc59f998fc01",
      "description": "This template is for more formal projects requiring a framework for process improvement and an auditable record of decisions.",
      "isDefault": false,
      "type": "system",
      "url": "https://dev.azure.com/devops-test-tfe/_apis/process/processes/27450541-8e31-4150-9947-dc59f998fc01",
      "name": "CMMI"
    },
    {
      "id": "adcc42ab-9882-485e-a3ed-7678f01f66bc",
      "description": "This template is flexible and will work great for most teams using Agile planning methods, including those practicing Scrum.",
      "isDefault": false,
      "type": "system",
      "url": "https://dev.azure.com/devops-test-tfe/_apis/process/processes/adcc42ab-9882-485e-a3ed-7678f01f66bc",
      "name": "Agile"
    }
  ]
}
{% endhighlight %}

The Agile template is the last one and you can see that it has the ID `adcc42ab-9882-485e-a3ed-7678f01f66bc`. With that information you can now create your project. Note that this is a POST request, which means that you need to add a body with the configuration information and also set the content type:

{% highlight http linenos %}
POST https://dev.azure.com/<your-new-org-name>/_apis/projects?api-version=5.1
Authorization: Bearer ...
Content-Type: application/json

{
  "name": "MyNewProject",
  "description": "My phantastic new project",
  "capabilities": {
    "versioncontrol": {
      "sourceControlType": "Git"
    },
    "processTemplate": {
      "templateTypeId": "adcc42ab-9882-485e-a3ed-7678f01f66bc"
    }
  }
}

HTTP/1.1 202 Accepted
...
{
  "id": "8c6d76bc-aee8-4953-a797-4570de290076",
  "status": "notSet",
  "url": "https://dev.azure.com/<your-new-org-name>/_apis/operations/8c6d76bc-aee8-4953-a797-4570de290076"
}
{% endhighlight %}

The result is a link to an operation because creating a new project might take a bit. If you call the provided URL, it will show you the current status of the operation and hopefully in the end, a `succeeded` status:

{% highlight http linenos %}
GET https://dev.azure.com/<your-new-org-name>/_apis/operations/8c6d76bc-aee8-4953-a797-4570de290076
Authorization: Bearer ...

HTTP/1.1 200 OK
...
{
  "id": "8c6d76bc-aee8-4953-a797-4570de290076",
  "status": "succeeded",
  "url": "https://dev.azure.com/<your-new-org-name>/_apis/operations/8c6d76bc-aee8-4953-a797-4570de290076",
  "_links": {
    "self": {
      "href": "https://dev.azure.com/<your-new-org-name>/_apis/operations/8c6d76bc-aee8-4953-a797-4570de290076"
    }
  }
}
{% endhighlight %}

With that, you have your new project in place and can reach it at `https://dev.azure.com/<your-new-org-name>/<your-new-project-name>`!

## The details: Tooling
I am happily using the amazing [REST Client extension][rest-client] of Visual Studio Code by Huachao Mao for a couple of years now, but other tools like [Postman][postman] or [Postwoman][postwoman] should work as well.

[DevOps-REST-API]: https://docs.microsoft.com/en-us/rest/api/azure/devops
[auth-options]: https://docs.microsoft.com/en-us/rest/api/azure/devops/?view=azure-devops-rest-5.1#authenticate
[my-information]: https://aex.dev.azure.com/me
[accounts-list]: https://docs.microsoft.com/en-us/rest/api/azure/devops/account/accounts/list?view=azure-devops-rest-5.1
[profiles-service]: https://docs.microsoft.com/en-us/rest/api/azure/devops/profile/profiles/get?view=azure-devops-rest-5.1
[projects-create]: https://docs.microsoft.com/en-us/rest/api/azure/devops/core/projects/create?view=azure-devops-rest-5.1
[process-templates]: https://docs.microsoft.com/en-us/azure/devops/boards/work-items/guidance/choose-process?view=azure-devops&tabs=agile-process
[processes-service]: https://docs.microsoft.com/en-us/rest/api/azure/devops/core/processes/list?view=azure-devops-rest-5.1
[rest-client]: https://marketplace.visualstudio.com/items?itemName=humao.rest-client
[postman]: https://www.postman.com/
[postwoman]: https://postwoman.io/
[arm]: https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/overview