---
layout: post
title: "Azure DevOps Simplify - the community extension to work more efficiently with Azure DevOps from VS Code"
permalink: azure-devops-simplify---the-community-extension-to-work-more-efficiently-with-azure-devops-from-vs-code
date: 2022-11-16 18:49:48
comments: false
description: "Azure DevOps Simplify - the community extension to work more efficiently with Azure DevOps from VS Code"
keywords: ""
image: /images/azdevops-vscode-simplify.png
categories:

tags:

---

Looking at the [Azure DevOps Roadmap][azdevops-roadmap] with lots of planned improvements across the board (pun intended) for 2023 and even further, it seems clear to me that Microsoft has ramped up their investment into the product again and as much as I love GitHub, I really love to see that. At the same time, the official [vscode-azdevops-msft-extension][VS Code Azure DevOps (Repositories) extension] has been deprecated. And while I get that to a degree, because there is amazing Git support directly in VS Code (and no one uses TFVC anymore[^1]), there are also missing features like assigning a work item to a commit or creating a branch connected to a work item. But don't despair, the great [David Feldhoff][david] (author of the amazing [AL CodeActions extension][al-codeactions]) and I created a small VS Code extension to help with that. We proudly present: [Azure DevOps Simplify - the community extension to work more efficiently with Azure DevOps from VS Code!][azdevops-vscode-simplify]. Of course, this is open source, and we are happy to take community contributions at the corresponding [GitHub repository tfenster/azdevops-vscode-simplify][github]

## The TL;DR

With this extension, you can currently do three things:

- Browse your Azure DevOps organizations, find a work item and assign it to a commit or create a branch linked to it
- Search for a work item and assign it to a commit

As a small bonus feature, you can also open a work item in your browser. Here is what it looks like:

<video width="100%" controls>
  <source type="video/mp4" src="/images/azdevops-simplify-walkthrough.mp4">
</video>

Please note that if you want a more comprehensive integration of Azure DevOps into VS Code (and much more) for Business Central developers, I can only recommend to take a look at [COSMO Alpaca][alpaca].

That's *what* you can do with it. In the details sections of this blog post I'm now going into *how* we did it to make it more easy for you to contribute. But there are already a lot of sessions (including my own), blog posts and the great [official VS Code docs][ext-docs] about creating VS Code extensions, so I don't want to go more deeply into that. Instead, I want to focus on the interaction with Azure DevOps and Git.

## The details: Fetching the Azure DevOps tree
The interaction with Azure DevOps is completely built using the [Azure DevOps REST API][azdevops-rest] and the code can be found in [azdevops-api.ts][azdevops-api.ts]. As one example, here is how we fetch the organizations:

{% highlight TypeScript linenos %}
export async function getOrganizations(): Promise<Organization[]> {
    try {
        let connection = getAzureDevOpsConnection();
        let memberId = await connection.getMemberId();
        // https://learn.microsoft.com/en-us/rest/api/azure/devops/account/accounts/list?view=azure-devops-rest-7.1&tabs=HTTP
        let responseAccounts = await connection.get(`https://app.vssps.visualstudio.com/_apis/accounts?memberId=${memberId}&api-version=6.0-preview.1`);
        let orgs = new Array<Organization>();
        await responseAccounts.value.forEach((account: any) => {
            orgs.push(new Organization(account.accountName, `https://dev.azure.com/${account.accountName}`,
                account.accountId, vscode.TreeItemCollapsibleState.Collapsed));
        });
        orgs.sort((a, b) => a.label.localeCompare(b.label));
        return orgs;
    } catch (error) {
        vscode.window.showErrorMessage(`An unexpected error occurred while retrieving organizations: ${error}`);
        console.error(error);
        return [];
    }
}
{% endhighlight %}

As you can see, this is pretty simple: After some initial setup, we call the "accounts" endpoint, parse the result and create our `TreeItem`s from there. The same strategy is applied for projects and for the work items, it is only slightly more complicated: We first need to run a [WIQL][wiql] query (line 7) to collect the IDs of the work items that we want, and then we get the details for those IDs (line 36). If we have more than 200 results, we need to iterate (lines 14-17), because the API returns a maximum of 200 work items per call:

{% highlight TypeScript linenos %}
async function loadWorkItems(query: string, orgUrl: string, projectUrl: string, considerMaxNumberOfWorkItems: boolean): Promise<any> {
    try {
        let connection = getAzureDevOpsConnection();
        let maxNumberOfWorkItemsParam = "";
        if (considerMaxNumberOfWorkItems) { maxNumberOfWorkItemsParam = `&$top=${maxNumberOfWorkItems()}`; }
        // https://learn.microsoft.com/en-us/rest/api/azure/devops/wit/wiql/query-by-wiql?view=azure-devops-rest-7.1&tabs=HTTP
        let responseWIIds = await connection.post(`${projectUrl}/_apis/wit/wiql?api-version=6.0${maxNumberOfWorkItemsParam}`, { "query": query });
        let wiIds: number[] = responseWIIds.workItems?.map((wi: any) => <Number>wi.id);

        if (wiIds?.length > 0) {
            let workItemPromises: Promise<any[]>[] = [];
            let skip = 0;
            let top = 200;
            do {
                workItemPromises.push(loadWorkItemPart(wiIds.slice(skip, skip + top), connection, orgUrl));
                skip += 200;
            } while (skip < wiIds.length);
            const resolvedWorkItemBlocks = await Promise.all<any[]>(workItemPromises);
            let workItems: any[] = [];
            for (const resolvedWorkItemBlock of resolvedWorkItemBlocks) { workItems = workItems.concat(resolvedWorkItemBlock); };
            workItems.sort(sortWorkItems);
            return { count: workItems.length, value: workItems };
        }
    } catch (error) {
        vscode.window.showErrorMessage(`An unexpected error occurred while retrieving work items: ${error}`);
        console.error(error);
    }
    return { count: 0, value: [] };

    async function loadWorkItemPart(wiIds: number[], connection: AzDevOpsConnection, orgUrl: string): Promise<any[]> {
        let bodyWIDetails = {
            "fields": ["System.Id", "System.Title", "System.State", "System.WorkItemType", "System.AssignedTo"],
            "ids": wiIds
        };
        // https://learn.microsoft.com/en-us/rest/api/azure/devops/wit/work-items/get-work-items-batch?view=azure-devops-rest-7.1&tabs=HTTP
        let workItemsPart: { count: number; value: any[]; } = await connection.post(`${orgUrl}/_apis/wit/workitemsbatch?api-version=6.0`, bodyWIDetails);
        return workItemsPart.value;
    }
}
{% endhighlight %}

## The details: Interacting with the VS Code git extension

The interaction with the (built-in) VS Code git extension is maybe a bit more interesting although even easier to implement, because it uses a very powerful mechanism. Again, this is all on one file, this time [git-api.ts][git-api.ts]. By getting a reference to the git extension, we can use a lot of the functionality that is already included, but from our own extension:

{% highlight TypeScript linenos %}
if (GitExtension.gitApi === undefined) {
    const gitExtension = vscode.extensions.getExtension("vscode.git");
    if (gitExtension) {
        GitExtension.gitApi = gitExtension.exports.getAPI(1);
    } else {
        vscode.window.showErrorMessage("Git extension not found. This extension is required for the full functionality of Azure DevOps Simplify.");
    }
}
{% endhighlight %}

This allows us to easily e.g. get the current repo:

{% highlight TypeScript linenos %}
public getRepo(): Repository | undefined {
    const repos = GitExtension.gitApi.repositories;
    if (repos && repos.length > 0) {
        return repos[0];
    } else {
        vscode.window.showErrorMessage("No Git repository found. This functionality only works when you have a Git repository open.");
    }
    return undefined;
}
{% endhighlight %}

Note that we (ok, I ;) ) have hard-coded `repos[0]` here, which means that we are currently not supporting a scenario where you have a workspace with multiple git repos and want to select which one two use. Instead, we will always use the first one for now, but this might change in the future. And if it really annoys you, feel free to create a PR!

Assigning a work item to a commit is also relatively easy. We need the `inputBox` of a repo, which is the box where you fill in your commit message. With that, we can either just put in our new commit message (a # followed by the ID of the work item, because then Azure DevOps automatically links the work item to the commit) in line 7 or append it to an already existing message in line 5:

{% highlight TypeScript linenos %}
public async appendToCheckinMessage(line: string): Promise<void> {
    await this.withSourceControlInputBox((inputBox: InputBox) => {
        const previousMessage = inputBox.value;
        if (previousMessage) {
            inputBox.value = previousMessage + "\n" + line;
        } else {
            inputBox.value = line;
        }
    });
}

private async withSourceControlInputBox(fn: (input: InputBox) => void) {
    const repo = this.getRepo();
    if (repo) {
        const inputBox = repo.inputBox;
        if (inputBox) {
            fn(inputBox);
        }
    }
}
{% endhighlight %}

## The details: Bringing both together - create a local and a remote branch, linked to a work item

The last part of the extension that I want to explain in a bit more detail is how we create a local and remote branch and link it to a work item. You can find this in the [azdevops-api.ts][azdevops-api.ts] file as well. First, we get the current repo again (line 2) and ask the user for the name of the new branch (lines 4-6). Then we get the `fetchUrl` of the `remote` (again, only the first is usable in the current implementation) and parse it to find the name of the repository (lines 10 and 11). With that, we can query the Azure DevOps REST API again for the details (line 12). Then we can use the API of the git extension to create a branch (line 14) and push it (line 15). This also locally switches to that branch. In the end, another request to the Azure DevOps REST API links the new remote branch and the work item (line 27).

{% highlight TypeScript linenos %}
public async createBranch() {
    const repo = getGitExtension().getRepo();
    if (repo) {
        let newBranch = await vscode.window.showInputBox({
            prompt: "Please enter the name of the new branch"
        });
        if (newBranch) {
            if (repo.state.HEAD?.upstream && repo.state.remotes.length > 0 && repo.state.remotes[0].fetchUrl) {
                // get substring after last slash
                let remoteRepoName = repo.state.remotes[0].fetchUrl;
                remoteRepoName = remoteRepoName.substring(remoteRepoName.lastIndexOf("/") + 1);
                let remoteRepo = await getAzureDevOpsConnection().get(`${this.parent.parent.url}/_apis/git/repositories/${remoteRepoName}?api-version=5.1-preview.1`);
                let upstreamRef = repo.state.HEAD.upstream;
                await repo.createBranch(newBranch, true);
                await repo.push(upstreamRef.remote, newBranch, true);
                let wiLink = {
                    "Op": 0,
                    "Path": "/relations/-",
                    "Value": {
                        "rel": "ArtifactLink",
                        "url": `vstfs:///Git/Ref/${this.parent.parent.id}%2F${remoteRepo.id}%2FGB${newBranch}`,
                        "attributes": {
                            "name": "Branch"
                        }
                    }
                };
                await getAzureDevOpsConnection().patch(`${this.parent.parent.parent.url}/_apis/wit/workItems/${this.wiId}?api-version=4.0-preview`, [wiLink], "application/json-patch+json");
                vscode.window.showInformationMessage(`Created branch ${newBranch} and linked it to work item ${this.wiId}`);
            } else {
                vscode.window.showErrorMessage("No upstream branch found. This functionality only works with an upstream branch.");
            }
        }
    }
}
{% endhighlight %}

We hope the extension will help you in your daily dev life and if you see anything that you want to improve or have ideas for new features, feel free to let us know or just create a Pull Request!

[wiql]: https://learn.microsoft.com/en-us/azure/devops/boards/queries/wiql-syntax?view=azure-devops
[azdevops-api.ts]: https://github.com/tfenster/azdevops-vscode-simplify/blob/main/src/api/azdevops-api.ts
[git-api.ts]: https://github.com/tfenster/azdevops-vscode-simplify/blob/main/src/api/git-api.ts
[azdevops-rest]: https://learn.microsoft.com/en-us/rest/api/azure/devops/?view=azure-devops-rest-7.1
[azdevops-roadmap]: https://learn.microsoft.com/en-us/azure/devops/release-notes/features-timeline
[vscode-azdevops-msft-extension]: https://github.com/microsoft/azure-repos-vscode
[david]: https://twitter.com/FeldhoffDavid
[al-code-actions]: https://marketplace.visualstudio.com/items?itemName=davidfeldhoff.al-codeactions
[azdevops-vscode-simplify]: tbd
[alpaca]: https://marketplace.cosmoconsult.com/product/?id=345E2CCC-C480-4DB3-9309-3FCD4065CED4&stext=alpaca
[ext-docs]: https://code.visualstudio.com/api/get-started/your-first-extension
[github]: https://github.com/tfenster/azdevops-vscode-simplify
[^1]: Right, dear Dynamics 365 Finance & SCM colleages ;) ?
