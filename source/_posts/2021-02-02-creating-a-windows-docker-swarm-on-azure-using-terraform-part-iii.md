---
layout: post
title: "Creating a Windows Docker Swarm on Azure using Terraform, part III: PowerShell scripts"
permalink: creating-a-windows-docker-swarm-on-azure-using-terraform-part-iii
date: 2021-02-02 09:00:00
comments: false
description: "Creating a Windows Docker Swarm on Azure using Terraform, part III: PowerShell scripts"
keywords: ""
image: /images/terraform-azure-swarm.png
categories:

tags:

---

After the overall setup in [part one][one] and the [Docker Swarm][docker-swarm], [Terraform][terraform], [OpenSSH][openssh] and [Docker Compose][docker-compose] setup for [Portainer][portainer] and [Traefik][traefik] in [part two][two], I want to walk you through the PowerShell scripts used during the setup of the Docker Swarm on Azure in this third part.

## The TL;DR
Most of the work is done in four scripts where the respective first script is called as VM extension:
- [mgrInitSwarmAndSetupTasks.ps1][mgrInitSwarmAndSetupTasks.ps1] to initialize the Swarm and create tasks for the rest of the manager setup
- [mgrConfig.ps1][mgrConfig.ps1] to actually do the rest of the manager setup
- [workerSetupTasks.ps1][workerSetupTasks.ps1] to create tasks for the worker setup
- [workerConfig.ps1][workerConfig.ps1] to actually do the worker setup

The reason for not putting everything in one script for the managers and one script for the workers is that the initialization of the manager, especially the first one, needs to happen before everything else, so I am doing this immediately. The rest can happen later, so I just create a task for that, so the initial script finishes. And I wanted to have simple hooks to be able to extend this whole setup either on first start or on restart of a manager or worker, so I also added tasks on restart for those config scripts. The rest are relatively straightforward scripts to [configure the jumpbox][jumpboxConfig.ps1], [set up the PowerShell profile][profile.ps1] and [mount the Azure File Share][mountAzFileShare.ps1]. 

## The details: Integration into the Terraform templates
The integration into the Terraform templates is conceptually always the same, as a Virtual Machine extension. It has a file URL where the script can be downloaded and a protected setting that has the command to execute. E.g. this is the Terraform resource to call the [mgrInitSwarmAndSetupTasks.ps1][mgrInitSwarmAndSetupTasks.ps1] script for the first manager:

{% highlight hcl linenos %}
resource "azurerm_virtual_machine_extension" "initMgr1" {
  name                       = "initMgr1"
  virtual_machine_id         = azurerm_windows_virtual_machine.mgr1.id
  ...

  settings = jsonencode({
    "fileUris" = [
      "https://raw.githubusercontent.com/cosmoconsult/azure-swarm/${var.branch}/scripts/mgrInitSwarmAndSetupTasks.ps1"
    ]
  })

  protected_settings = jsonencode({
    "commandToExecute" = "powershell -ExecutionPolicy Unrestricted -File mgrInitSwarmAndSetupTasks.ps1 
    -externaldns \"${local.name}.${var.location}.cloudapp.azure.com\" -email \"${var.eMail}\" 
    -branch \"${var.branch}\" -additionalPreScript \"${var.additionalPreScriptMgr}\" 
    -additionalPostScript \"${var.additionalPostScriptMgr}\" -dockerdatapath \"${var.dockerdatapath}\" 
    -name \"${local.name}\" -storageAccountName \"${azurerm_storage_account.main.name}\" 
    -storageAccountKey \"${azurerm_storage_account.main.primary_access_key}\" 
    -adminPwd \"${random_password.password.result}\" -isFirstmgr 
    -authToken \"${var.authHeaderValue}\" -debugScripts \"${var.debugScripts}\""
  })
}
{% endhighlight %}

You can see that quite some parameters are used to configure everything as needed, and you can see that almost all are read from Terraform variables like `$var.eMail` or properties of Terraform resources like `${azurerm_storage_account.main.name}`.

## The details: Initializing and configuring the managers
The manager initialization and configuration happens in two parts: First the Swarm itself is set up in [mgrInitSwarmAndSetupTasks.ps1][mgrInitSwarmAndSetupTasks.ps1]and then a task for everything else in [mgrConfig.ps1][mgrConfig.ps1] is started, as explained in the TL;DR. On all managers (and workers, as we will see later), the firewall needs to have three ports open, so that happens before initializing the Swarm itself:

{% highlight powershell linenos %}
New-NetFirewallRule -DisplayName "Allow Swarm TCP" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 2377, 7946 | Out-Null
New-NetFirewallRule -DisplayName "Allow Swarm UDP" -Direction Inbound -Action Allow -Protocol UDP -LocalPort 4789, 7946 | Out-Null
{% endhighlight %}

Then if this is the first manager, the initialization happens, as you can see using a fixed IP address as explained in [part two][two]. Also take note that the default address pool for containers in the Swarm is `10.10.0.0/16` to make sure this doesn't collide with the Azure infrastructure.

{% highlight powershell linenos %}
Invoke-Expression "docker swarm init --advertise-addr 10.0.3.4 --default-addr-pool 10.10.0.0/16"
{% endhighlight %}

After that, the admin password is stored as Swarm secret so that we can later retrieve it when starting Portainer, also explained in [part two][two].

{% highlight powershell linenos %}
Out-File -FilePath ".\adminPwd" -NoNewline -InputObject $adminPwd -Encoding ascii
docker secret create adminPwd ".\adminPwd"
Remove-Item ".\adminPwd"
{% endhighlight %}

With the Swarm in place, we can now retrieve the tokens to join the swarm as worker and as manager:

{% highlight powershell linenos %}
$token = Invoke-Expression "docker swarm join-token -q worker"
$tokenMgr = Invoke-Expression "docker swarm join-token -q manager"
{% endhighlight %}

As those tokens will be needed by any other manager or worker, they are stored in the Azure Key Vault. We gave the VMs access to that (the first manager has write access, all the others only read access), but we need to get an access token to authenticate. For that, we call a special URL which returns the access token and then use that to make an HTTP PUT call to the Key Vault API

{% highlight powershell linenos %}
$content = [DownloadWithRetry]::DoDownloadWithRetry('http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fvault.azure.net', 5, 10, $null, $null, $true) | ConvertFrom-Json
$KeyVaultToken = $content.access_token
$joinCommand = "docker swarm join --token $token 10.0.3.4:2377"
$Body = @{
    value = $joinCommand
}
$result = Invoke-WebRequest -Uri https://$name-vault.vault.azure.net/secrets/JoinCommand?api-version=2016-10-01 -Method PUT -Headers @{Authorization = "Bearer $KeyVaultToken" } -Body (ConvertTo-Json $Body) -ContentType "application/json" -UseBasicParsing

$joinCommandMgr = "docker swarm join --token $tokenMgr 10.0.3.4:2377"
$Body = @{
    value = $joinCommandMgr
}
$result = Invoke-WebRequest -Uri https://$name-vault.vault.azure.net/secrets/JoinCommandMgr?api-version=2016-10-01 -Method PUT -Headers @{Authorization = "Bearer $KeyVaultToken" } -Body (ConvertTo-Json $Body) -ContentType "application/json" -UseBasicParsing
{% endhighlight %}

As I have seen occasions where this didn't work reliably, I also try to read the secrets to make sure they are in place and have even wrapped it in a try / catch block and do 10 retries if anything fails

{% highlight powershell linenos %}
$secretJson = (Invoke-WebRequest -Uri https://$name-vault.vault.azure.net/secrets/JoinCommand?api-version=2016-10-01 -Method GET -Headers @{Authorization = "Bearer $KeyVaultToken" } -UseBasicParsing).content | ConvertFrom-Json
Write-Debug "worker join command result: $secretJson"
$secretJsonMgr = (Invoke-WebRequest -Uri https://$name-vault.vault.azure.net/secrets/JoinCommandMgr?api-version=2016-10-01 -Method GET -Headers @{Authorization = "Bearer $KeyVaultToken" } -UseBasicParsing).content | ConvertFrom-Json
Write-Debug "manager join command result: $secretJsonMgr"

if ($secretJson.value -eq $joinCommand -and $secretJsonMgr.value -eq $joinCommandMgr) {
    Write-Debug "join commands are matching"
    $tries = 11
}
{% endhighlight %}

If one of the other managers runs that script, it also needs to get the auth token, but then does an HTTP GET call to retrieve the Swarm join token and executes it. I had quite some trouble on earlier Windows versions to get that to work reliably when I tried to use 1-Core managers and only could make it work well with 2-Core machines. I lately did some tests with Windows Server 2004 and that seems to be a lot better but because of those issues, this part is a lot more complicated and involves jobs and checking their states than necessary. Therefore, I'll show a simplified version here, but you can check the actual code [here][join] if you want

{% highlight powershell linenos %}
$content = [DownloadWithRetry]::DoDownloadWithRetry('http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fvault.azure.net', 5, 10, $null, $null, $true) | ConvertFrom-Json
$KeyVaultToken = $content.access_token
$secretJson = [DownloadWithRetry]::DoDownloadWithRetry("https://$name-vault.vault.azure.net/secrets/JoinCommandMgr?api-version=2016-10-01", 30, 10, "Bearer $KeyVaultToken", $null, $false) | ConvertFrom-Json
Invoke-Expression "$(secretJson.value)"
{% endhighlight %}

The rest downloads the other scripts and calls them or creates the task to call the on restart.

The [mgrConfig.ps1][mgrConfig.ps1] script does some housekeeping and, if it is called on the first manager, creates an overlay network for all Swarm services which should be available through traefik. Then it downloads the Docker Compose template file explained in [part one][one], replaces the variables in the file with actual values (line 7 and 8) and deploys it.

{% highlight powershell linenos %}
if ($isFirstMgr) {
    Invoke-Expression "docker network create --driver=overlay traefik-public" | Out-Null
    Start-Sleep -Seconds 10

    [DownloadWithRetry]::DoDownloadWithRetry("https://raw.githubusercontent.com/cosmoconsult/azure-swarm/$branch/configs/docker-compose.yml.template", 5, 10, $null, 's:\compose\base\docker-compose.yml.template', $false)
    $template = Get-Content 's:\compose\base\docker-compose.yml.template' -Raw
    $expanded = Invoke-Expression "@`"`r`n$template`r`n`"@"
    $expanded | Out-File "s:\compose\base\docker-compose.yml" -Encoding ASCII

    Invoke-Expression "docker stack deploy -c s:\compose\base\docker-compose.yml base"
}
{% endhighlight %}

On all managers, it sets up SSH by installing it (along with vim) through [chocolatey][chocolatey], downloading the public SSH key from the Key Vault, that was uploaded through the Terraform deployment and configuring SSH. Again, I am showing a slightly simplified and less fault tolerant version here to show you the idea, and you can get the real implementation [here][ssh]

{% highlight powershell linenos %}
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
choco feature enable -n allowGlobalConfirmation
choco install --no-progress --limit-output vim
choco install --no-progress --limit-output openssh -params '"/SSHServerFeature"'

[DownloadWithRetry]::DoDownloadWithRetry("https://raw.githubusercontent.com/cosmoconsult/azure-swarm/$branch/configs/sshd_config_wpwd", 5, 10, $null, 'C:\ProgramData\ssh\sshd_config', $false)

$secretJson = [DownloadWithRetry]::DoDownloadWithRetry("https://$name-vault.vault.azure.net/secrets/sshPubKey?api-version=2016-10-01", 5, 10, "Bearer $KeyVaultToken", $null, $false) | ConvertFrom-Json
$secretJson.value | Out-File 'c:\ProgramData\ssh\administrators_authorized_keys' -Encoding utf8

### adapted (pretty much copied) from https://gitlab.com/DarwinJS/ChocoPackages/-/blob/master/openssh/tools/chocolateyinstall.ps1#L433
$path = "c:\ProgramData\ssh\administrators_authorized_keys"
$acl = Get-Acl -Path $path
$acl.SetSecurityDescriptorSddlForm("O:BAD:PAI(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)")
Set-Acl -Path $path -AclObject $acl
### end of copy
{% endhighlight %}

## The details: Initializing and configuring the workers
The initialization and configuration of the workers is also split into the first part in [workerSetupTasks.ps1][workerSetupTasks.ps1] which more or less only sets up the scheduled task to call [workerConfig.ps1][workerConfig.ps1]. The config script does the same Swarm networking setup and SSH install with chocolatey. Joining the Swarm also looks very similar to what happens on the manager, of course using the worker join token, not the manager join token. It also has an option to pull images when the worker comes up, so that if you know in advance that you will run a specific workload, the images are already pulled when the request comes in.

{% highlight powershell linenos %}
Write-Host "pull $images"
if (-not [string]::IsNullOrEmpty($images)) {
    $imgArray = $images.Split(',');
    foreach ($img in $imgArray) {
        Write-Host "pull $img"
        Invoke-Expression "docker pull $img" | Out-Null
    }
}
{% endhighlight %}

## The details: Configuring the jumpbox, setting up the PowerShell profiles and mounting the Azure File Share
The jumpbox initialization in [jumpboxConfig.ps1][jumpboxConfig.ps1] is even simpler, it only sets up SSH and does the following three things which are also happening on the workers and managers:
- It sets up the PowerShell profile so that it shows the current hostname because otherwise it can become very confusing if you are jumping between the different machines. For that, it downloads the following script [profile.ps1][profile.ps1] and puts it into the special place `$PROFILE.AllUsersAllHosts` which means it is executed whenever a PowerShell sessions starts on that machine:
{% highlight powershell linenos %}
function prompt { "PS [$env:COMPUTERNAME]:$($executionContext.SessionState.Path.CurrentLocation)$('>' * ($nestedPromptLevel + 1)) " }
{% endhighlight %}
- It makes PowerShell the default when an OpenSSH connection comes in (default is cmd) with the following line
{% highlight powershell linenos %}
New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -PropertyType String -Force
{% endhighlight %}
- It mounts the Azure File Share that is common storage between all nodes with the following script [mountAzFileShare.ps1][mountAzFileShare.ps1]. It is important to set the access rights with icacls.exe as seen below because otherwise the containers might not have then necessary access
{% highlight powershell linenos %}
$secpassword = ConvertTo-SecureString $storageAccountKey -AsPlainText -Force
$creds = New-Object System.Management.Automation.PSCredential("Azure\$storageAccountName", $secpassword)
New-SmbGlobalMapping -RemotePath "\\$storageAccountName.file.core.windows.net\share" -Credential $creds -LocalPath "$($driveLetter):" -Persistent $true -RequirePrivacy $true
Invoke-Expression "icacls.exe $($driveLetter):\ /grant 'Everyone:(OI)(CI)(F)'"
{% endhighlight %}

## The details: Setting up additional scripts
The last thing to mention is that there are hook points for additional scripts in for all the different machines (jumpbox, workers, managers). To accomplish this, all scripts have something similar to the following in the beginning:

{% highlight powershell linenos %}
if ($additionalPreScript -ne "") {
    [DownloadWithRetry]::DoDownloadWithRetry($additionalPreScript, 5, 10, $authToken, 'c:\scripts\additionalPreScript.ps1', $false)
    
    & 'c:\scripts\additionalPreScript.ps1' -branch "$branch" -isFirstMgr:$isFirstMgr -authToken "$authToken"
}
{% endhighlight %}

And then in the end something similar to the following is also in place:

{% highlight powershell linenos %}
if (-not $restart) {
    if ($additionalPostScript -ne "") {
        [DownloadWithRetry]::DoDownloadWithRetry($additionalPostScript, 5, 10, $authToken, 'c:\scripts\additionalPostScript.ps1', $false)
        & 'c:\scripts\additionalPostScript.ps1' -branch "$branch" -externaldns "$externaldns" -isFirstMgr:$isFirstMgr -authToken "$authToken"
    }
}
else {
    if ($additionalPostScript -ne "") {
        & 'c:\scripts\additionalPostScript.ps1' -branch "$branch" -externaldns "$externaldns" -isFirstMgr:$isFirstMgr -authToken "$authToken" -restart 
    }
}
{% endhighlight %}

As you can see, I implemented my own download function which is embedded in every script instead of using one of the default Cmdlets, mainly for two reasons:

- Sometimes the external download fails when the machine is just starting, so I needed a retry and that becomes available in PowerShell only in V6 and later while I am mostly stuck with V5.1.
- I wanted an easy way to add an auth token. If the parameter is set, it will try to download using the auth token and also retry without, in case you have more than one download location, maybe one with auth and one without.

With that, I hope you a good overview of what is happening during setup and configuration of the Swarm and all the components in the PowerShell scripts.

[one]: https://tobiasfenster.io/creating-a-docker-swarm-on-azure-using-terraform-part-i
[two]: https://tobiasfenster.io/creating-a-docker-swarm-on-azure-using-terraform-part-ii
[docker-swarm]: https://docs.docker.com/engine/swarm/
[terraform]: https://www.terraform.io 
[traefik]: https://traefik.io/
[portainer]: https://www.portainer.io/
[openssh]: https://docs.microsoft.com/en-us/windows-server/administration/openssh/openssh_overview
[docker-compose]: https://docs.docker.com/compose/
[jumpboxConfig.ps1]: https://github.com/cosmoconsult/azure-swarm/blob/c6333e4392679ced82f70539e78c377995a0a41b/scripts/jumpboxConfig.ps1
[mgrConfig.ps1]: https://github.com/cosmoconsult/azure-swarm/blob/c6333e4392679ced82f70539e78c377995a0a41b/scripts/mgrConfig.ps1
[mgrInitSwarmAndSetupTasks.ps1]: https://github.com/cosmoconsult/azure-swarm/blob/c6333e4392679ced82f70539e78c377995a0a41b/scripts/mgrInitSwarmAndSetupTasks.ps1
[mountAzFileShare.ps1]: https://github.com/cosmoconsult/azure-swarm/blob/master/scripts/mountAzFileShare.ps1
[profile.ps1]: https://github.com/cosmoconsult/azure-swarm/blob/c6333e4392679ced82f70539e78c377995a0a41b/scripts/profile.ps1
[workerConfig.ps1]: https://github.com/cosmoconsult/azure-swarm/blob/c6333e4392679ced82f70539e78c377995a0a41b/scripts/workerConfig.ps1
[workerSetupTasks.ps1]: https://github.com/cosmoconsult/azure-swarm/blob/c6333e4392679ced82f70539e78c377995a0a41b/scripts/workerSetupTasks.ps1
[join]: https://github.com/cosmoconsult/azure-swarm/blob/c6333e4392679ced82f70539e78c377995a0a41b/scripts/mgrInitSwarmAndSetupTasks.ps1#L153-L206
[chocolatey]: https://chocolatey.org
[ssh]: https://github.com/cosmoconsult/azure-swarm/blob/c6333e4392679ced82f70539e78c377995a0a41b/scripts/mgrConfig.ps1#L86-L135