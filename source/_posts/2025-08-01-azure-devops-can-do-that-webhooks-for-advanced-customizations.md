---
layout: post
title: "Azure DevOps can do that? Webhooks for advanced customizations"
permalink: azure-devops-can-do-that-webhooks-for-advanced-customizations
date: 2025-08-01 04:26:22
comments: false
description: "Azure DevOps can do that? Webhooks for advanced customizations"
keywords: ""
image: /images/azdevops-webhook.png
categories:

tags:

---

If you are using [Azure DevOps][azdo], you may have wanted for some kind of customization that wasn't available out of the box. E.g. we want the area path of a work item to automatically change once it has reached a certain column in a board[^1], but there is no feature to make that happen out of the box. But Azure DevOps does have [Webhooks][webhooks], which we could use to achieve that. Setting up such a webhook is [well documented][setup] and quite easy, so I won't get into the details here. But how does a backend need to look like to respond to that call? This I'll explain in this blog post.

## The TL;DR

If you just want to give it a try using a [GitHub Codespace][codespace], fork my repository [https://github.com/tfenster/azdevops-webhook-explorer](https://github.com/tfenster/azdevops-webhook-explorer) and start the codespace. Everything should be preconfigured through the [devcontainer.json][devc] configuration file. Then do the following:

- Hit F5 to start debugging
- Once the application has started, you should see two ports come up. Change the visibility on the second one (8443) to "public" via the right-click menu and copy the address, again via the right-click menu. This should put something like `https://cuddly-capybara-q74jxp677rj24q7j-8443.app.github.dev/` into your clipboard, but with different random names and numbers.
![a screenshot showing the ports of a GitHub Codespace](images/azdevops-webhook-ports.png)
{: .centered}
- Use that URL with the additional path `/webhook/inspect` as URL when configuring your webhook, e.g. when a work item is updated.
![a screenshot showing the configuration including the url setting of a webhook](images/azdevops-webhook-url.png)
{: .centered}
- Once you update a work item, you should see that request come in to your Codespace and it should log the payload to the debug console.

## The details: The code for inspecting

The first step to analyze what is happening when such a webhook is executed ist to take a look at the payload. The official docs mentioned above suggest to use a public service like pastebin, but that maybe you can't or dont want to use that. Instead you can run the little application mentioned above to just inspect the payload. The code is trivial:

{% highlight csharp linenos %}
var app = WebApplication.CreateBuilder().Build();

app.MapPost("/webhook/inspect", async (HttpRequest request) =>
{
    using var reader = new StreamReader(request.Body);
    var body = await reader.ReadToEndAsync();
    Console.WriteLine($"Received webhook data:\n{body}");
    return Results.Ok();
});
{% endhighlight %}

That's it. It just creates an endpoint that reacts to a POST request and writes the content to the console. So really nothing fancy, but it helps to understand what is shared to a webhook. To pick up our example from above, if this is called after a work item is updated, the (abbreviated) log would show something like this:

{% highlight json linenos %}
{
    "subscriptionId": "2f0622c6-fe08-4357-a9e2-788668ad37a7",
    "notificationId": 1,
    "id": "29e26c11-013d-451c-868c-f897a6400d2a",
    "eventType": "workitem.updated",
    "publisherId": "tfs",
    "message": {
        "text": "User Story #1 (Test with changed title) updated by Tobias Fenster\r\n(https://dev.azure.com/repro-publishing-issue/web/wi.aspx?pcguid=557fa63a-3fb6-460a-866b-cfcae8fedd66&id=1)",
        "html": "<a href=\"https://dev.azure.com/repro-publishing-issue/web/wi.aspx?pcguid=557fa63a-3fb6-460a-866b-cfcae8fedd66&amp;id=1\">User Story #1</a> (Test with changed title) updated by Tobias Fenster",
        "markdown": "[User Story #1](https://dev.azure.com/repro-publishing-issue/web/wi.aspx?pcguid=557fa63a-3fb6-460a-866b-cfcae8fedd66&id=1) (Test with changed title) updated by Tobias Fenster"
    },
    "detailedMessage": {
        "text": "User Story #1 (Test with changed title) updated by Tobias Fenster\r\n(https://dev.azure.com/repro-publishing-issue/web/wi.aspx?pcguid=557fa63a-3fb6-460a-866b-cfcae8fedd66&id=1)\r\n\r\n- New Title: Test with changed title\r\n",
        "html": "<a href=\"https://dev.azure.com/repro-publishing-issue/web/wi.aspx?pcguid=557fa63a-3fb6-460a-866b-cfcae8fedd66&amp;id=1\">User Story #1</a> (Test with changed title) updated by Tobias Fenster<ul>\r\n<li>New Title: Test with changed title</li></ul>",
        "markdown": "[User Story #1](https://dev.azure.com/repro-publishing-issue/web/wi.aspx?pcguid=557fa63a-3fb6-460a-866b-cfcae8fedd66&id=1) (Test with changed title) updated by Tobias Fenster\r\n\r\n* New Title: Test with changed title\r\n"
    },
    "resource": {
        "id": 2,
        "workItemId": 1,
        "rev": 2,
        "revisedBy": {
            "id": "72449079-0c93-6274-848f-7e657a28086d",
            "name": "Tobias Fenster <tfenster@4psbau.de>",
            "displayName": "Tobias Fenster",
            "url": "https://spsprodneu1.vssps.visualstudio.com/A5fc63d1b-ae70-4eb7-8657-56f682d08852/_apis/Identities/72449079-0c93-6274-848f-7e657a28086d",
            "_links": {
                "avatar": {
                    "href": "https://dev.azure.com/repro-publishing-issue/_apis/GraphProfile/MemberAvatars/aad.NzI0NDkwNzktMGM5My03Mjc0LTg0OGYtN2U2NTdhMjgwODZk"
                }
            },
            "uniqueName": "tfenster@4psbau.de",
            "imageUrl": "https://dev.azure.com/repro-publishing-issue/_apis/GraphProfile/MemberAvatars/aad.NzI0NDkwNzktMGM5My03Mjc0LTg0OGYtN2U2NTdhMjgwODZk",
            "descriptor": "aad.NzI0NDkwNzktMGM5My03Mjc0LTg0OGYtN2U2NTdhMjgwODZk"
        },
        "revisedDate": "9999-01-01T00:00:00Z",
        "fields": {
            "System.Rev": {
                "oldValue": 1,
                "newValue": 2
            },
            "System.AuthorizedDate": {
                "oldValue": "2025-07-27T14:03:59.473Z",
                "newValue": "2025-07-27T14:04:08.447Z"
            },
            "System.RevisedDate": {
                "oldValue": "2025-07-27T14:04:08.447Z",
                "newValue": "9999-01-01T00:00:00Z"
            },
            "System.ChangedDate": {
                "oldValue": "2025-07-27T14:03:59.473Z",
                "newValue": "2025-07-27T14:04:08.447Z"
            },
            "System.Watermark": {
                "oldValue": 1,
                "newValue": 2
            },
            "System.Title": {
                "oldValue": "Test",
                "newValue": "Test with changed title"
            }
        },
        "_links": {
            "self": {
                "href": "https://dev.azure.com/repro-publishing-issue/07afe328-1c60-4995-8420-0a70c400fc5d/_apis/wit/workItems/1/updates/2"
            },
            "workItemUpdates": {
                "href": "https://dev.azure.com/repro-publishing-issue/07afe328-1c60-4995-8420-0a70c400fc5d/_apis/wit/workItems/1/updates"
            },
            "parent": {
                "href": "https://dev.azure.com/repro-publishing-issue/07afe328-1c60-4995-8420-0a70c400fc5d/_apis/wit/workItems/1"
            },
            "html": {
                "href": "https://dev.azure.com/repro-publishing-issue/web/wi.aspx?pcguid=557fa63a-3fb6-460a-866b-cfcae8fedd66&id=1"
            }
        },
        "url": "https://dev.azure.com/repro-publishing-issue/07afe328-1c60-4995-8420-0a70c400fc5d/_apis/wit/workItems/1/updates/2",
        "revision": {
            "id": 1,
            "rev": 2,
            "fields": {
                "System.AreaPath": "repro",
                "System.TeamProject": "repro",
                "System.IterationPath": "repro",
                "System.WorkItemType": "User Story",
                "System.State": "New",
                "System.Reason": "New",
                "System.CreatedDate": "2025-07-27T14:03:59.473Z",
                "System.CreatedBy": "Tobias Fenster <tfenster@4psbau.de>",
                "System.ChangedDate": "2025-07-27T14:04:08.447Z",
                "System.ChangedBy": "Tobias Fenster <tfenster@4psbau.de>",
                "System.CommentCount": 0,
                "System.Title": "Test with changed title",
                "System.BoardColumn": "New",
                "System.BoardColumnDone": false,
                "Microsoft.VSTS.Common.StateChangeDate": "2025-07-27T14:03:59.473Z",
                "Microsoft.VSTS.Common.Priority": 2,
                "Microsoft.VSTS.Common.ValueArea": "Business",
                "WEF_3139F49F3CA94BDB98022BF3C1AF3733_Kanban.Column": "New",
                "WEF_3139F49F3CA94BDB98022BF3C1AF3733_Kanban.Column.Done": false
            },
            "multilineFieldsFormat": {},
            "_links": {
                "self": {
                    "href": "https://dev.azure.com/repro-publishing-issue/07afe328-1c60-4995-8420-0a70c400fc5d/_apis/wit/workItems/1/revisions/2"
                },
                "workItemRevisions": {
                    "href": "https://dev.azure.com/repro-publishing-issue/07afe328-1c60-4995-8420-0a70c400fc5d/_apis/wit/workItems/1/revisions"
                },
                "parent": {
                    "href": "https://dev.azure.com/repro-publishing-issue/07afe328-1c60-4995-8420-0a70c400fc5d/_apis/wit/workItems/1"
                }
            },
            "url": "https://dev.azure.com/repro-publishing-issue/07afe328-1c60-4995-8420-0a70c400fc5d/_apis/wit/workItems/1/revisions/2"
        }
    },
    "resourceVersion": "1.0",
    "resourceContainers": {
        "collection": {
            "id": "557fa63a-3fb6-460a-866b-cfcae8fedd66",
            "baseUrl": "https://dev.azure.com/repro-publishing-issue/"
        },
        "account": {
            "id": "5fc63d1b-ae70-4eb7-8657-56f682d08852",
            "baseUrl": "https://dev.azure.com/repro-publishing-issue/"
        },
        "project": {
            "id": "07afe328-1c60-4995-8420-0a70c400fc5d",
            "baseUrl": "https://dev.azure.com/repro-publishing-issue/"
        }
    },
    "createdDate": "2025-07-27T14:04:14.970126Z"
}
{% endhighlight %}

A few things to highlight:

- The `eventType` in line 5 shows you which kind of event triggered the webhook call, in this case `workitem.updated`. You can find a full list across "Build and release", "Pipeline", "Code", Service connection", "Work item" and "Advanced security" events in the [documentation][events]
- The `revisedBy` gives you a way to figure out who made the change (from line 21 onwards)
- In my scenario, I am interested in fields that changed, which is why I would look at the `fields` from line 36 onwards, where I can see the old and new values for every changed field.

Depending on the event you listen to, this will of course be different, but that is why having a little "inspector" handy is so useful: You just run the service, configure the webhook and take a look at the payload to understand what is coming in and how you can make the most of it.

## The details: The code for reacting to a work item update

Now if you figured out what exactly you want, it makes sense to create a model class so that you can interact with the payload in a strongly typed way. The easiest way nowadays in my opionion is to just ask [GitHub Copilot][ghc] to create it based on the payload you get through an inspection as explained above. I won't bore you with the details as it is just a C# representation of the JSON payload above, but you can find it [here][model] if you want to take a look at it.

Handling the content would look something like this if you want to e.g. react on a changed title:

{% highlight csharp linenos %}
app.MapPost("webhook/updatedWorkItem", async (HttpRequest request) =>
{
    Console.WriteLine("Updated work item received");
    using var reader = new StreamReader(request.Body);
    var body = await reader.ReadToEndAsync();
    var payload = JsonSerializer.Deserialize<AzDevOpsWebhookPayload>(body, new JsonSerializerOptions()
    {
        PropertyNameCaseInsensitive = true
    });
    if (payload == null)
    {
        return Results.BadRequest("Invalid payload");
    }

    if (payload.EventType == "workitem.updated" && payload.Resource?.Fields != null)
    {
        if (payload.Resource.Fields.TryGetValue("System.Title", out var titleField))
        {
            Console.WriteLine($"Work item updated: {payload.Resource.WorkItemId}, Old Title: {titleField.OldValue} --> New Title: {titleField.NewValue}");
        }
    }
    return Results.Ok();
});
{% endhighlight %}

Again, this reacts to a `POST` request (line 1), gets the body (lines 4 and 5) and deserializes it into the `payload` object (lines 6-9). Now we can work with the content:

- Line 15 checks if the `EventType` is the right one and whether we have any changed fields
- Line 17 tries to read the `System.Title` field
- And then in line 19 we handle it, in this case only showing the old and new title in the logs.

With that code and the GitHub Codespace in place, you can play around, see what Azure DevOps is sending and react to it as your requirements demand.

## The details: Deploying it to production, e.g. an AKS cluster

But how can we run this in production? Nowadays, chances are that you have a Kubernetes cluster somewhere in your reach. Deploying it there is quite easy and in my case with an [Azure Kubernetes Service (AKS)][aks] cluster, it would look like this although it probably would work the same somewhere else:

{% highlight yaml linenos %}
kind: Namespace
apiVersion: v1
metadata:
  name: azdevops-webhook-explorer-linux
  labels:
    name: azdevops-webhook-explorer-linux
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: azdevops-webhook-explorer
  namespace: azdevops-webhook-explorer-linux
spec:
  replicas: 1
  selector:
    matchLabels:
      app: azdevops-webhook-explorer
  template:
    metadata:
      labels:
        app: azdevops-webhook-explorer
    spec:
      containers:
        - name: azdevops-webhook-explorer
          image: tobiasfenster/azdevops-webhook-explorer:latest
          imagePullPolicy: Always
          resources:
            limits:
              memory: "1024Mi"
              cpu: "1000m"
      nodeSelector:
        kubernetes.io/os: linux
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: azdevops-webhook-explorer-ingress
  namespace: azdevops-webhook-explorer-linux
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /webhook/$1

spec:
  ingressClassName: nginx
  rules:
    - host: fps-alpaca.westeurope.cloudapp.azure.com
      http:
        paths:
          - backend:
              service:
                name: azdevops-webhook-explorer
                port:
                  number: 8080
            path: /azdevops-webhook-explorer/(.*)
            pathType: Prefix
  tls:
    - hosts:
        - fps-alpaca.westeurope.cloudapp.azure.com
---
apiVersion: v1
kind: Service
metadata:
  name: azdevops-webhook-explorer
  namespace: azdevops-webhook-explorer-linux
spec:
  selector:
    app: azdevops-webhook-explorer
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080
{% endhighlight %}

First we have the `Namespace`, kind of the "folder" to keep the kubernetes resources together, shown in lines 1-6. The we have the `Deployment`, which among others defines the container image to use (line 25), the number of instances or `replicas` (line 14) and the maximum `reosurces` to use (lines 27-30). Then we have the `Ingress` which is a way to receive traffic from the outside by defining a `host` (lines 45 and 57, the latter one for the TLS setup) and `path` on which to react (line 53). Because of the `annotation` in line 40, the incoming request to `/azdevops-webhook-explorer/` is redirected to `/webhook/` and the rest of the incoming path is appended through the `(.*)` in the path and the `$1` in the annotation. You can also see in lines 49-52 that the request is sent to a `service` called `azdevops-webhook-explorer` on port 8080. Whic brings us to the last part, the `Service` which is connected to the `Deployment` via the `selector` in lines 65 and 66 where you can see the corresponding `matchLabels` in line 16 and 17.

The `Dockerfile` to create an image out of the code explained above is very standard, but if you want to take a look, you can find it [here][dockerfile].

This should hopefully give you an idea how you can easily develop such a webhook using a GitHub Codespace and how you can as easily deploy it to a Kubernetes environment like the Azure Kubernetes Service.

[azdo]: https://azure.microsoft.com/en-us/products/devops
[^1]: The underlying requirement is that we have two boards and work items are assigned to each of them based on the area path. Once a work item has reached a certain column in the first board, it should automatically be moved to the second one, which means the area path has to change.
[webhooks]: https://learn.microsoft.com/en-us/azure/devops/service-hooks/services/webhooks?toc=%2Fazure%2Fdevops%2Fmarketplace-extensibility%2Ftoc.json&view=azure-devops
[setup]: https://learn.microsoft.com/en-us/azure/devops/service-hooks/services/webhooks?toc=%2Fazure%2Fdevops%2Fmarketplace-extensibility%2Ftoc.json&view=azure-devops#send-json-representation-to-a-service
[codespace]: https://github.com/features/codespaces
[devc]: https://github.com/tfenster/azdevops-webhook-explorer/blob/69646e366cb8894e84ef061f380dbbd741e21611/.devcontainer/devcontainer.json
[events]: https://learn.microsoft.com/en-us/azure/devops/service-hooks/events?toc=%2Fazure%2Fdevops%2Fmarketplace-extensibility%2Ftoc.json&view=azure-devops
[ghc]: https://github.com/features/copilot
[model]: https://github.com/tfenster/azdevops-webhook-explorer/blob/69646e366cb8894e84ef061f380dbbd741e21611/AzDevOpsModels.cs
[dockerfile]: https://github.com/tfenster/azdevops-webhook-explorer/blob/39b76f451371d90ecf4720be4a41d21a555e87ed/Dockerfile
[aks]: https://azure.microsoft.com/en-us/products/kubernetes-service