---
layout: post
title: "Creating a combined work item list from multiple Azure DevOps organizations and why that matters for GDPR"
permalink: creating-a-combined-work-item-list-from-multiple-azure-devops-organizations-and-why-that-matters-for-gdpr
date: 2020-02-23 15:26:57
comments: true
description: "Creating a combined work item list from multiple Azure DevOps organizations and why that matters for GDPR"
keywords: ""
categories:
image: /images/azdevops-wi-reader-klein.png

tags:

---

When working with Azure DevOps including customers, you probably are using multiple organizations as some customers will want you to run everything and some will want to use their own tenant and organization. Even if every project runs on your side, GDPR requirements probably will force you to create separate organizations, but more on that later. While Azure DevOps provides a lot of additional value in that setup as well, there are some areas where cross-organizational features are missing. The most obvious to me is the inability to have a list of assigned work items across all organizations. To solve that issue, I've created a small tool that allows you to run a WIQL[^1] query across organizations and get a list of combined results.

## The TL;DR
If you want to give it a try, the quickest way is to run it as Docker container. In order to do that you need to give it the information which organizations you want to query, what query to run and which fields from the work items to show. The configuration file e.g. could look like this

{% highlight json linenos %}
{
    "orgsWithPATs": [
        {
            "pat": "secretStuff",
            "orgs": [
                "cc-demo-devops",
                "cc-East-Assets"
            ]
        },
        {
            "pat": "differentSecretStuff",
            "orgs": [
                "cc-project"
            ]
        }
    ],
    "query": "SELECT [System.Id] FROM workitemLinks WHERE ([Source].[System.WorkItemType] IN ('User Story', 'Bug') AND [Source].[System.State] IN ('Active', 'Resolved') ) AND ([Target].[System.WorkItemType] = 'Task' AND NOT [Target].[System.State] IN ('Closed') ) ORDER BY [System.Id] MODE (MayContain)",
    "linkType": "System.LinkTypes.Hierarchy-Forward",
    "fields": [
        {
            "id": "System.WorkItemType",
            "label": "Type"
        },
        {
            "id": "System.AssignedTo",
            "label": "AssignedTo"
        },
        {
            "id": "System.State",
            "label": "State"
        },
        {
            "id": "System.Tags",
            "label": "Tags"
        },
        {
            "id": "System.TeamProject",
            "label": "Project"
        }
    ]
}
{% endhighlight %}

With such a config set up in a file called `config.json` in place e.g. in a folder `c:\azdevops-wi-reader\config`, you could do a `docker run -v c:\azdevops-wi-reader\config:c:\config -p 8080:80 tobiasfenster/azdevops-wi-reader:0.9.1-1809`[^2] and would end up with something similar to the following running on http://localhost:8080

![remote debug](/images/azdevops-wi-reader.gif)
{: .centered}

You can sort and filter and use the titles of the work items or parent work items to directly jump to the work item. As always, feedback and improvement ideas are very welcome, ideally as issues or pull requests on [GitHub][GitHub].

## More details on the configuration
The configuration consists of two parts: The first is an array of organizations to query and PATs (personal access tokens) to use to get access. You can create a PAT by following the excellent instructions [here][azdevops-pats]. Make sure to give it access to "all accessible organizations" (a setting beneath "Organization") and enable "Read" access for work items. Then you can put the PAT together with the names of all organizations this PAT can access into the list (line 3-15 above):

{% highlight json linenos %}
{
    "orgsWithPATs": [
        {
            "pat": "secretStuff",
            "orgs": [
                "cc-demo-devops",
                "cc-East-Assets"
            ]
        },
        {
            "pat": "differentSecretStuff",
            "orgs": [
                "cc-project"
            ]
        }
    ]
    ...
}
{% endhighlight %}

The second part defines how you want to query for work items in your organizations and which fields from each work item you want to show:

{% highlight json linenos %}
{
    ...
    "query": "SELECT [System.Id] FROM workitemLinks WHERE ([Source].[System.WorkItemType] IN ('User Story', 'Bug') AND [Source].[System.State] IN ('Active', 'Resolved') ) AND ([Target].[System.WorkItemType] = 'Task' AND NOT [Target].[System.State] IN ('Closed') ) ORDER BY [System.Id] MODE (MayContain)",
    "linkType": "System.LinkTypes.Hierarchy-Forward",
    "fields": [
        {
            "id": "System.WorkItemType",
            "label": "Type"
        },
        {
            "id": "System.AssignedTo",
            "label": "AssignedTo"
        },
        {
            "id": "System.State",
            "label": "State"
        },
        {
            "id": "System.Tags",
            "label": "Tags"
        },
        {
            "id": "System.TeamProject",
            "label": "Project"
        }
    ]
}
{% endhighlight %}

The query is defined in WIQL but instead of understanding how that works, you can just define a query using the GUI in Azure DevOps and then use e.g. the excellent [Wiql Editor][wiqleditor] extension to show the raw WIQL. Just copy that to your config file and you should be ready to go. If you use a query of type "flat list", you can ignore the "link type" element in the config as your query won't return links in that case. But if you use the query type "work items and direct links", then you need to provide the link type, e.g. "System.LinkTypes.Hierarchy-Forward" in my example.

Last but not least you define which fields should be shown and what the label for those fields should be. Note that the work item title will always be included and contain a link to the work item and also if you add the System.AssignedTo field, the name and email address of the assigned person will be added. And if you have a list with links, then you will automatically get the parent title including the URL.

## The implementation details
First of all, from an architectural standpoint I decided to go with an integrated instead of a micro-service approach as I wanted to keep it a simple as possible to understand and run. I also decided to go with [Blazor][Blazor] as I wanted to give that a try since I first saw it at the MVP Summit in 2018 but never found a good project to do that. It really is great fun to work with and is a very good fit with my nowadays C#-centric development skills as I only had limited chances to work with JavaScript frontend frameworks (which makes it somewhat frustrating to find your way in Angular, React or Vue). I also implemented a small CLI-based tool to allow easy Excel exporting, so the project is structured into that CLI frontend, a shared part including the Azure DevOps access logic and the web application. All are separate projects combined into a workspace, so the easiest way to get up and running with the code is to clone it from GitHub and then just open the .workspace file in Visual Studio Code.

I didn't use any of the available libraries to access Azure DevOps and just used the REST API as I find it easy enough to handle. In order to load the work items as quickly as possible, I decided to add some async parallelism, but really only a basic implementation for that as well.

## Why this matters for GDPR
Unfortunately, if you add guest users to projects and have projects by more than one customer in the same organization, you are in a bit of trouble with GDPR. It mandates that you need to let a customer know which other companies might have access to personal data and because Microsoft decided to make all guest users across projects visible in e.g. the people pickers, the names are very much available. Now you could in theory provide your customers with a list of other customers and let them accept that, but you would always need to update that list when you get a new customer or lose a customer, which isn't really realistic. So the only option for now is to create a separate organization for every customer, which is only a bad workaround as you can't e.g. get a list of all your work items across organizations (the reason for my little tool) or plan capacity across organizations. 

There is already an [issue][issue] about this on the developer community where Microsoft collects feature requests for Azure DevOps, so please go ahead and vote for it. I've been in contact with some of the PMs for Azure DevOps and while they actually agreed that this is a violation of GDPR, they pointed to the very bad workaround of creating one organization per customer as a "solution". I hope we can raise some awareness for this issue in order to get a real solution.


[^1]: WIQL is the Work Item Query Language, a SQL-like language that is used to define queries in Azure DevOps.
[^2]: Or image `tobiasfenster/azdevops-wi-reader:1.0-1809` if you run on Windows Server 2019 or Win 10 1809

[GitHub]: https://github.com/tfenster/azdevops-wi-reader
[Blazor]: https://dotnet.microsoft.com/apps/aspnet/web-apps/blazor
[azdevops-pats]: https://docs.microsoft.com/en-us/azure/devops/organizations/accounts/use-personal-access-tokens-to-authenticate?view=azure-devops&tabs=preview-page#create-personal-access-tokens-to-authenticate-access
[wiqleditor]: https://marketplace.visualstudio.com/items?itemName=ottostreifel.wiql-editor
[issue]: https://developercommunity.visualstudio.com/idea/365834/better-permission-management-user-interface-identi.html