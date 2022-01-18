---
layout: post
title: "Using AAD authentication for development against a Business Central container"
permalink: using-aad-authentication-for-development-against-a-business-central-container
date: 2022-01-18 17:01:52
comments: false
description: "Using AAD authentication for development against a Business Central container"
keywords: ""
image: /images/vscode-aad-bc.png
categories:

tags:

---

Since a long time, it is possible to use [Azure AD][aad] [authentication][auth] in your Business Central OnPrem environment, whether containerized or not. But what isn't possible - or at least is [documented as impossible][docs] - is to use AAD authentication when developing in VS Code and publishing extension, downloading symbols, debugging etc.. If you are like me and get annoyed very quickly if you have to do things that aren't exactly necessary (and not fun...), you were probably as frustrated as I that this seemingly easy option to avoid juggling with users and passwords wasn't available. But thanks to a post in the BC Development Yammer community, I found out that it actually works and with some help by Kalman Beres and Steffen Balslev of Microsoft (thank you!), managed to get it up and running. So, finally we have SSO for development as well! 

## The TL;DR

If you want to just use it, here is the quick rundown:

1. Wait until a version of [bccontainerhelper][bcch] with [this PR][pr] included appears. That should be either 3.0.1 when it is released or 3.0.1-preview357.
2. If you have the rights to create an Azure AD [app registration][appreg] and want to run the container locally, then you can use a script like this:
{% highlight powershell linenos %}
$containerName = "bcserver"
$credential = New-Object pscredential -ArgumentList 'admin', (ConvertTo-SecureString -String '<your-secret-password>' -AsPlainText -Force)
$AadUserName = '<your-add-user>'
$aadCredential = New-Object pscredential -ArgumentList $AadUserName, (ConvertTo-SecureString -String '<your-other-secret-password>' -AsPlainText -Force)

$publicDns = $containerName
$publicWebBaseUrl = "http://$publicDns/BC"

$appIdUri = "https://$($containerName).$($AadUserName.Split('@')[1])/BC"
$AdProperties = Create-AadAppsForBC -AadAdminCredential $aadCredential -appIdUri $appIdUri -publicWebBaseUrl $publicWebBaseUrl

New-BcContainer `
     -containerName $containerName `
     -accept_eula `
     -artifact (Get-BCArtifactUrl -country de -type OnPrem) `
     -auth AAD `
     -Credential $credential `
     -imageName "mybc" `
     -authenticationEMail $AadUserName `
     -PublicDnsName $publicDns `
     -AadTenant "$($AadUserName.Split('@')[1])" `
     -AadAppId "$($AdProperties.SsoAdAppId)" `
     -AadAppIdUri $appIdUri
{% endhighlight %}
Of course you will need to change the password in line 2 (although it won't be used as we use AAD for authentication), the user in line 3 (this will be used both for login in BC and for creating the app registration, so this accounts needs the necessary permissions for that) and the password in line 4, corresponding to the user in line 3.
3. Try to open the BC web client in a browser at http://bcserver/BC.
4. If you do this for the first time, you will be asked to consent to the app registration. If and when [this][grant] gets resolved, this step will no longer be needed
5. After that, you should see Business Central in all its glory, authenticated through Azure AD. Now on to VS Code...
6. Create a launch.json file that looks something like this:
{% highlight json linenos %}
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Your own server",
            "request": "launch",
            "type": "al",
            "environmentType": "OnPrem",
            "server": "http://bcserver/",
            "serverInstance": "BC",
            "authentication": "AAD",
            "startupObjectId": 22,
            "startupObjectType": "Page",
            "breakOnError": true,
            "launchBrowser": true,
            "enableLongRunningSqlStatements": true,
            "enableSqlInformationDebugger": true,
            "tenant": "default",
            "primaryTenantDomain": "<your-primary-tenant-domain>"
        }
    ]
}
{% endhighlight %}
Again, replace the primary tenant domain in line 19 with the correct value. If you are not sure, go to the [Azure Portal][portal] -> Azure Active Directory and you will find it directly on the overview page. It might be something with .onmicrosoft.com in the end, it might be something different.
7. Run "AL: Download symbols". You will get a notification that asks you to sign in by clicking "Copy & Open". With that, a new browser window will open where you can paste the code, click "Next", select the Azure AD account and confirm with "Continue".
8. Go back to VS Code and you should see that the symbols are downloaded. Hitting F5 for deployment and everything else should also just work!

Here is a walkthrough of the result. As you can see, no need to enter my password anywhere, as I am already logged in to Windows. I think this would be different if MFA was active, but since this is my playground tenant, I have it deactivated.

<video width="100%" controls>
  <source type="video/mp4" src="/images/vscode-aad-bc-walkthrough.mp4">
</video>

## The details: Things to be aware of

There actually is not a lot more to this. Bccontainerhelper is doing a great job as so often, but you can also just take a look at the parameters used for the container and do it directly, no secret magic here. However, there are some things to be aware of:

- If you run this with a sandbox container by e.g. changing `OnPrem` to `Sandbox` in line 15 of the first script above, you will get a multi-tenant container with one tenant called "default". In that scenario, the requests to the container by the VS Code extension need to have `tenant=default`, which seems to not work at the moment. There are two workarounds I can see: Create a tenant with a different name and use that, or start the sandbox container with `-multitenant:$false` to get a single-tenant sandbox container. However, this second option might break other scenarios.

- If you run this with a bccontainerhelper version older than 3.0.1-preview357, you can also enter the container with `Enter-BcContainer -containerName bcserver` and then run the following two commands:
```
Set-NAVServerConfiguration BC -KeyName ValidAudiences -KeyValue "$(Get-NAVServerConfiguration BC -KeyName ValidAudiences);https://api.businesscentral.dynamics.com"
Restart-NAVServerInstance BC
```
This will add the audience `https://api.businesscentral.dynamics.com` to the list of valid audiences, because the AL extension seems to create a bearer token with that specific audience. As bccontainerhelper already has the workaround with a soon-to-be released version, you probably don't need to worry about that.

- If you run your container not on your laptop, but somewhere else, make sure to set the right public web base URL (line 7 in the first script above). The app registration needs this to redirect properly and will just fail if this is wrong. The app ID URI (line 9) however can stay the same, at least according to my tests.

- I was told that you might have to add the following setting into the `CustomSettings.json` file of your service instance:
```
<add key="ForceExtensionAllowedTargetLevel" value="true" />
```
However, at some point in my tests I forgot to add it, and it turns out that I didn't need it. But I also might not have tested the scenario where it matters, so keep it in mind, maybe you will need it.

[aad]: https://docs.microsoft.com/en-us/azure/active-directory/fundamentals/active-directory-whatis
[auth]: https://docs.microsoft.com/en-us/dynamics365/business-central/dev-itpro/administration/users-credential-types#credential-types
[docs]: https://docs.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/devenv-json-files#publish-to-local-server-settings
[bcch]: https://www.powershellgallery.com/packages/bccontainerhelper
[pr]: https://github.com/microsoft/navcontainerhelper/pull/2270
[appreg]: https://docs.microsoft.com/en-us/azure/active-directory/develop/quickstart-register-app
[grant]: https://github.com/microsoft/navcontainerhelper/issues/2153
[portal]: https://portal.azure.com