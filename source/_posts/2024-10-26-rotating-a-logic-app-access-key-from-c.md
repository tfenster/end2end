---
layout: post
title: "Rotating a Logic App access key from C#"
permalink: rotating-a-logic-app-access-key-from-c
date: 2024-10-26 08:33:47
comments: false
description: "Rotating a Logic App access key and getting the signature from C#"
keywords: ""
image: /images/csharp-logic-app.png
categories:

tags:

---

This is just a short one as I recently came across a problem that was a bit more difficult to solve than it should be and maybe someone with the same struggle will come across this: How to rotate an [Azure Logic App][ala] access key and get the signature from C#?

## The TL;DR

If you know how, it actually is very easy as you can see in the following snippet:

{% highlight csharp linenos %}
// Define your Azure credentials and subscription
var credential = new DefaultAzureCredential();

// Authenticate and create a client
var armClient = new ArmClient(credential, SUBSCRIPTION_ID);

// Get the Logic App resource
var logicWorkflowResource = armClient.GetLogicWorkflowResource(LogicWorkflowResource.CreateResourceIdentifier(SUBSCRIPTION_ID, RESOURCE_GROUP, LOGIC_APP_NAME));

// Rotate the access key
var regenerateKeyParameters = new LogicWorkflowRegenerateActionContent
{
    KeyType = LogicKeyType.Primary
};
await logicWorkflowResource.RegenerateAccessKeyAsync(regenerateKeyParameters);

 // Get the trigger URL signature
var logicWorkflowTriggerResource = logicWorkflowResource.GetLogicWorkflowTrigger(LOGIC_APP_TRIGGER_NAME);
var callbackUrl = logicWorkflowTriggerResource.Value.GetCallbackUrl();
var signature = callbackUrl.Value.Queries.Sig;
{% endhighlight %}

That's it. You get the client, you call the RegenerateAccessKeyAsync action, you get the Logic App trigger (for historical reasons call "Logic Workflow trigger") and extract the signature. Unfortunately, this is not documented.

## The details: What GitHub Copilot said

Nowadays, for questions like this, I typically ask GitHub Copilot and it came up with the following for regenerating the access key:

{% highlight csharp linenos %}
// Define your Azure details
var subscriptionId = "your-subscription-id";
var resourceGroupName = "your-resource-group-name";
var logicAppName = "your-logic-app-name";

// Authenticate using DefaultAzureCredential
var credential = new DefaultAzureCredential();

// Create Logic Management Client
var logicManagementClient = new LogicManagementClient(subscriptionId, credential);

// Regenerate the primary access key
var regenerateAccessKeyParameters = new RegenerateActionParameter
{
    KeyType = KeyType.Primary
};

await logicManagementClient.WorkflowTriggers.RegenerateAccessKeyAsync(resourceGroupName, logicAppName, regenerateAccessKeyParameters);
{% endhighlight %}

Looks good, right? Unfortunately, this uses a deprecated API and doesn't even compile with the current NuGet packages that Copilot referenced as well. Something similar happens when I ask it for code to get the signature of the access URL. Lesson of the story: GitHub Copilot might give you very reasonable look answers that are just not currect, even in widely used languages like C#. 

[ala]: https://learn.microsoft.com/en-us/azure/logic-apps/logic-apps-overview