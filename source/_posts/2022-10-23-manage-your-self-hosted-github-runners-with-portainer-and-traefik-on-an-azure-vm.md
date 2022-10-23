---
layout: post
title: "Manage your self hosted GitHub Runners with Portainer and Traefik on an Azure VM with Docker"
permalink: manage-your-self-hosted-github-runners-with-portainer-and-traefik-on-an-azure-vm
date: 2022-10-23 13:25:47
comments: false
description: "Manage your self-hosted GitHub Runners with Portainer and Traefik on an Azure VM with Docker"
keywords: ""
image: /images/github runner on azure docker vm with traefik and portainer.png
categories:

tags:

---

Inspired by [this][portainer-blog] very interesting blog post by [Portainer][portainer], I want to share something that I have been using for quite some time now as you might not need the full flexibility of what is described in that blog post, and you might have a need for Windows-based runners, which seems to be an [issue][issue] there at the moment. I want to explain how easily you can set up a Windows Server host on Azure, preconfigured with Portainer and [Traefik][traefik] as a reverse proxy to take care of network security including out of the box https support with [Let's Encrypt][le] and then deploy a containerized GitHub runner using a Portainer application template.

## The TL;DR

The first step is to find my "Windows Docker host with Portainer and Traefik pre-installed" template in the [Azure Quickstart Template gallery][azqtg]. Instead of directly deploying, go to the GitHub link and deploy it from there, as it will give you a better UI (more in the details). Fill in the required fields and deploy. After the deployment is completed, you still need to wait for approx. 10-15 minutes until the Traefik and Portainer container images are downloaded and the containers have started. This is what it looks like with a bit of fast forwarding, as you can see in some places:

<video width="100%" controls>
  <source type="video/mp4" src="/images/create portainer traefik ssh host.mp4">
</video>

After that, you have a Windows Server VM on Azure with Portainer for managing your containerized workloads and SSH connectivity with only key-based authentication. The next step is to deploy the GitHub runner. For that, I am using a [Portainer application template][portainer-template] from my own fork of the official Portainer repo for that purpose, just to show you how easy that is. Again, you fill in the required information and very quickly you have your GitHub runner, registered on your repo!

<video width="100%" controls>
  <source type="video/mp4" src="/images/set up github runner.mp4">
</video>

## The details: Optimizing the deployment UI

As I mentioned above, I would suggest going through the GitHub deployment link, because that includes optimized UI. The reason for that is the [createUiDefinition.json][ui] file, which defines what is displayed on the deployment screen. An example of what that can do is the email entry textbox:

{% highlight yaml linenos %}
...
{
    "name": "email",
    "type": "Microsoft.Common.TextBox",
    "label": "eMail address for Let's Encrypt validation",
    "placeholder": "your.name@example.com",
    "defaultValue": "",
    "toolTip": "eMail address for Let's Encrypt validation",
    "constraints": {
        "required": true,
        "regex": "^[\\S+@\\S+.\\S+]{7,100}$",
        "validationMessage": "Please enter a valid eMail address"
    },
    "visible": true
},
...
{% endhighlight %}

As you can see, you can define a label, a placeholder, a default value and a tool tip to make it easier for the user to understand what that field is about. You can also define constraints to make the field mandatory, a regular expression for validation and a potential error message if the entered value doesn't match that expression. Take a look at the full file for more ideas of what you can do with it like dropdowns, recommendations, user / password combos, SSH keys and more. 

If you want to really dig into what you can do with the UI definition, you can find a [nice overview][ui-docs] and [all the details][ui-details] in the official documentation. And a super helpful tool is the [sandbox][ui-sandbox] where you can put in your UI definition file and see what it will look like in the Azure Portal.

## The details: The host VM setup

The host VM setup is straight-forward, as you can see if you [visualize][armviz] the [ARM template][template] (what is that? Check the [docs][ARM]!) that is used to deploy the VM: The VM with network setup, a data disk and some setup scripts. Probably the most interesting is the [setup script][setup], where you can first see the disk setup (lines 12-17) for the data disk, the installation of packages with [Chocolatey][choco] (lines 20-25) and the configuration of [OpenSSH][openssh], PowerShell and [Docker][docker] (lines 28-52). In the end, the password file for Portainer is prepared as this is the only way to set a default password there (line 55), [Docker compose][compose] is downloaded (line 58), the variables in the compose file describing the Portainer and Traefik deployment are set (lines 60-62) and then the container deployment is started (lines 64 and 65)

{% highlight PowerShell linenos %}
param (
    $mail,
    $publicdnsname,
    $adminPwd,
    $basePath,
    $publicSshKey
)

$ProgressPreference = 'SilentlyContinue' 

# format disk and create folders
Get-Disk | Where-Object partitionstyle -eq 'raw' | Initialize-Disk -PartitionStyle MBR -PassThru | New-Partition -UseMaximumSize -DriveLetter F | Format-Volume -FileSystem NTFS -Confirm:$false -Force
New-Item -Path f:\le -ItemType Directory | Out-Null
New-Item -Path f:\le\acme.json | Out-Null
New-Item -Path f:\dockerdata -ItemType Directory | Out-Null
New-Item -Path f:\portainerdata -ItemType Directory | Out-Null
New-Item -Path f:\compose -ItemType Directory | Out-Null

# install vim and openssh using chocolatey
[DownloadWithRetry]::DoDownloadWithRetry("https://chocolatey.org/install.ps1", 5, 10, $null, ".\chocoInstall.ps1", $false)
& .\chocoInstall.ps1
choco feature enable -n allowGlobalConfirmation
choco install --no-progress --limit-output vim
choco install --no-progress --limit-output pwsh
choco install --no-progress --limit-output openssh -params '"/SSHServerFeature"'

# configure OpenSSH, make pwsh the default shell, show hostname in shell and restart sshd
Copy-Item "$basePath\sshd_config_wopwd" 'C:\ProgramData\ssh\sshd_config'
$path = "c:\ProgramData\ssh\administrators_authorized_keys"
"$publicSshKey" | Out-File -Encoding utf8 -FilePath $path
$acl = Get-Acl -Path $path
$acl.SetSecurityDescriptorSddlForm("O:BAD:PAI(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)")
Set-Acl -Path $path -AclObject $acl
New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value "C:\Program Files\PowerShell\7\pwsh.exe" -PropertyType String -Force
'function prompt { "PS [$env:COMPUTERNAME]:$($executionContext.SessionState.Path.CurrentLocation)$(''>'' * ($nestedPromptLevel + 1)) " }' | Out-File -FilePath "$($PROFILE.AllUsersAllHosts)" -Encoding utf8
Restart-Service sshd

# relocate docker data
Stop-Service docker
$dockerDaemonConfig = @"
{
    `"data-root`": `"f:\\dockerdata`"
}
"@
$dockerDaemonConfig | Out-File "c:\programdata\docker\config\daemon.json" -Encoding ascii
# avoid https://github.com/docker/for-win/issues/12358#issuecomment-964937374
Remove-Item 'f:\dockerdata\panic.log' -Force -ErrorAction SilentlyContinue | Out-Null
New-Item 'f:\dockerdata\panic.log' -ItemType File -ErrorAction SilentlyContinue | Out-Null
# avoid containers stuck in "create"
Add-MpPreference -ExclusionPath 'C:\Program Files\docker\'
Add-MpPreference -ExclusionPath 'f:\dockerdata'
Start-Service docker

# prepare password file for portainer
$adminPwd | Out-File -NoNewline -Encoding ascii "f:\portainerdata\passwordfile"

# download compose, the compose file and deploy it
[DownloadWithRetry]::DoDownloadWithRetry("https://github.com/docker/compose/releases/download/1.29.2/docker-compose-Windows-x86_64.exe", 5, 10, $null, "$($Env:ProgramFiles)\Docker\docker-compose.exe", $false)

$template = Get-Content (Join-Path $basepath 'docker-compose.yml.template') -Raw
$expanded = Invoke-Expression "@`"`r`n$template`r`n`"@"
$expanded | Out-File "f:\compose\docker-compose.yml" -Encoding ASCII

Set-Location "f:\compose"
Invoke-Expression "docker-compose up -d"
...
{% endhighlight %}

The [compose file][docker-compose.yml] first defines which image to use for Traefik (line 5) and the startup parameters (lines 9-17), followed by the volumes used in the Traefik container (lines 19-24), the ports (line 26) and the labels (lines 28-33). Noteworthy are that the Traefik container needs access to the Docker engine through the npipe volume and that Traefik itself has its dashboard configured (line 9, see the Traefik [docs][traefik-docs] to understand what that can do), but is disabled for reverse proxy handling by Traefik (line 28), so if you want to see and use the dashboard, you need to set that to `true`. Then we have the Portainer container with its image (line 36) and command, including a reference to the password file (line 38) that you have seen generated above. It also has volumes (lines 41-44) including the npipe mount of the Docker engine and labels (lines 46-55), this time with Traefik enabled (line 46), because the whole point of the setup is to make Portainer available through Traefik. Also note how there is no port configured for the Portainer container to make sure that all traffic goes through Traefik.

{% highlight yaml linenos %}
version: '3.7'

services:
  traefik:
    image: tobiasfenster/traefik-for-windows:latest
    container_name: traefik
    command:
#      - --log.level=DEBUG
      - --api.dashboard=true
      - --providers.docker=true
      - --providers.docker.exposedbydefault=false
      - --providers.docker.endpoint=npipe:////./pipe/docker_engine
      - --entrypoints.websecure.address=:443
      - --certificatesresolvers.myresolver.acme.tlschallenge=true
      - --certificatesresolvers.myresolver.acme.email=$email
      - --certificatesresolvers.myresolver.acme.storage=c:/le/acme.json
      - --serversTransport.insecureSkipVerify=true
    volumes:
      - source: 'f:/le'
        target: 'C:/le'
        type: bind
      - source: '\\.\pipe\docker_engine'
        target: '\\.\pipe\docker_engine'
        type: npipe
    ports:
      - 443:443
    labels:
      - traefik.enable=false
      - traefik.http.routers.api.entrypoints=websecure
      - traefik.http.routers.api.tls.certresolver=myresolver
      - traefik.http.routers.api.rule=Host(``$publicdnsname``) && (PathPrefix(``/api``) || PathPrefix(``/dashboard``))
      - traefik.http.routers.api.service=api@internal
      - traefik.http.services.api.loadBalancer.server.port=8080

  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    command: --admin-password-file c:/data/passwordfile
    restart: always
    volumes:
      - f:/portainerdata:c:/data
      - source: '\\.\pipe\docker_engine'
        target: '\\.\pipe\docker_engine'
        type: npipe
    labels:
      - traefik.enable=true
      - traefik.http.routers.portainer.rule=Host(``$publicdnsname``) && PathPrefix(``/portainer/``)
      - traefik.http.routers.portainer.entrypoints=websecure
      - traefik.http.routers.portainer.tls.certresolver=myresolver
      - traefik.http.routers.portainer.service=portainer@docker
      - traefik.http.services.portainer.loadBalancer.server.scheme=http
      - traefik.http.services.portainer.loadBalancer.server.port=9000
      - traefik.http.middlewares.portainer.stripprefix.prefixes=/portainer
      - traefik.http.middlewares.limit.buffering.maxRequestBodyBytes=500000000
      - traefik.http.routers.portainer.middlewares=portainer@docker, limit@docker

networks:
  default:
    external:
      name: nat
{% endhighlight %}

This should give you an idea of the general setup for the VM, Traefik and Portainer. The OpenSSH setup is basically the exact same as already explained in [a previous blog post][openssh-config], so I won't repeat that here.

## The details: The Portainer application template

The last part I want to explain in a bit more detail is the Portainer application template, because that is in my opinion an underappreciated and undersold feature of Portainer. With application templates you can predefine all the standard, non-changing parts of your container deployments, while keeping some parts configurable that are presented to the user in a nice UI, as you can see in the second walkthrough above. There are multiple ways to set up your own templates (check the [docs][portainer-custom-template]), but the easiest in my opinion is to just create a fork of the [official repo for that purpose][portainer-template-repo]. In that fork, you only need [very few changes][changes] to make your own template appear:

You define your own docker-compose.yml template, which in my case looks like this. Note the variables in lines 13-15 which are later presented as input fields to the user:
{% highlight yaml linenos %}
version: "3.7"

services:
  runner-github-runner-windows:
    image: tobiasfenster/github-runner-windows:ltsc2022
    deploy:
      replicas: 1
    volumes:
      - source: '\\.\pipe\docker_engine\'
        target: '\\.\pipe\docker_engine\'
        type: npipe
    environment:
      - GITHUBREPO_OR_ORG=${REPO_OR_ORG}
      - GITHUBPAT=${PAT}
      - GITHUBRUNNERNAME=${RUNNER_NAME}

networks:
  default:
    name: nat
{% endhighlight %}
How the runners themselves work, I have again already shared in a [previous blog post][github-runners].

Then you add a reference to that file and you add labels and descriptions for the variables to the main file, `templates-2.0.json`
{% highlight json linenos %}
{
    "type": 3,
    "title": "GitHub Runner",
    "description": "GitHub Runner",
    "categories": ["PaaS"],
    "platform": "Windows",
    "logo": "",
    "repository": {
    "url": "https://github.com/tfenster/templates",
    "stackfile": "stacks/github-runner/docker-compose.yml"
    },
    "env": [
        {
            "name": "REPO_OR_ORG",
            "label": "Repository or organization of the runner",
            "description": "The repository or organization you want your runner to connect to"
        },
        {
            "name": "PAT",
            "label": "Personal Access Token for connection",
            "description": "The Personal Access Token use by the runner to connect to GitHub"
        },
        {
            "name": "RUNNER_NAME",
            "label": "Name of the runner (appears in GitHub settings)",
            "description": "The name of the runner as it appears in the action settings on GitHub. Will be 'self-hosted' if left empty",
            "default": "self-hosted"
        }
    ]
}
{% endhighlight %}

I hope this gives you an idea about my general setup for (Windows-based) self-hosted GitHub runners and you can use that for your own projects!

[portainer-blog]: https://www.portainer.io/blog/gitops-with-portainer-using-github-actions
[portainer]: https://portainer.io
[issue]: https://github.com/actions-runner-controller/actions-runner-controller/issues/1001
[traefik]: https://traefik.io
[le]: https://letsencrypt.org/
[azqtg]: https://azure.microsoft.com/en-us/resources/templates/
[portainer-template]: https://docs.portainer.io/user/docker/templates
[ui]: https://github.com/tfenster/azure-quickstart-templates/blob/master/application-workloads/traefik/docker-portainer-traefik-windows-vm/createUiDefinition.json
[ui-docs]: https://learn.microsoft.com/en-us/azure/azure-resource-manager/managed-applications/create-uidefinition-overview
[ui-details]: https://learn.microsoft.com/en-us/azure/azure-resource-manager/managed-applications/create-uidefinition-elements
[ui-sandbox]: https://learn.microsoft.com/en-us/azure/azure-resource-manager/managed-applications/test-createuidefinition
[ARM]: https://learn.microsoft.com/en-us/azure/azure-resource-manager/templates/overview
[armviz]: http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-quickstart-templates%2Fmaster%2Fapplication-workloads%2Ftraefik%2Fdocker-portainer-traefik-windows-vm%2Fazuredeploy.json
[template]: https://github.com/Azure/azure-quickstart-templates/blob/df064d1b459f4230dfbcd94aa24b795dd79e2340/application-workloads/traefik/docker-portainer-traefik-windows-vm/azuredeploy.json
[setup]: https://github.com/Azure/azure-quickstart-templates/blob/df064d1b459f4230dfbcd94aa24b795dd79e2340/application-workloads/traefik/docker-portainer-traefik-windows-vm/setup.ps1
[choco]: https://chocolatey.org
[openssh]: https://openssh.org
[docker]: https://docker.com
[compose]: https://docs.docker.com/compose/
[docker-compose.yml]: https://github.com/Azure/azure-quickstart-templates/blob/df064d1b459f4230dfbcd94aa24b795dd79e2340/application-workloads/traefik/docker-portainer-traefik-windows-vm/configs/docker-compose.yml.template
[traefik-docs]: https://doc.traefik.io/traefik/operations/dashboard/
[openssh-config]: https://tobiasfenster.io/creating-a-windows-docker-swarm-on-azure-using-terraform-part-ii#the-details-configuring-openssh
[portainer-custom-template]: https://docs.portainer.io/user/docker/templates/custom
[portainer-template-repo]: https://github.com/portainer/templates
[changes]: https://github.com/portainer/templates/compare/portainer:2d2575f...tfenster:337567e
[github-runners]: https://tobiasfenster.io/building-docker-images-for-multiple-windows-server-versions-using-self-hosted-github-runners#the-details-using-self-hosted-containerized-github-runners