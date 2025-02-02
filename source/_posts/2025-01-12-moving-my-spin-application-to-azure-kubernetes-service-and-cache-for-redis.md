---
layout: post
title: "Moving my Spin application to Azure (Kubernetes Service and Cache for Redis)"
permalink: moving-my-spin-application-to-azure-kubernetes-service-and-cache-for-redis
date: 2025-01-12 08:00:44
comments: false
description: "Moving my Spin application to Azure (Kubernetes Service and Cache for Redis)"
keywords: ""
image: /images/spin-aks-redis.png
categories:

tags:

---

Due to a technical limitation[^1] in the [Fermyon][fermyon] [Cloud][fermyon-cloud], I decided to move [Verified Bluesky][vb] to the [Azure Kubernetes Service][aks] with [SpinKube][fermyon-spinkube], using[Azure Cache for Redis][azredis] as backend for the [Spin][fermyon-spin] [Key-Value store][spin-kv], and finally using a dedicated domain (verifiedbsky.net) for it. In this blog post, I'll explain the infrastructure setup, how to use it in Spin, the Continuous Deployment setup and the configuration of the domain.

**Update:** The technical limitation mentioned above has been lifted, so Verified Bluesky is now running in the Fermyon Cloud again! If you for whatever reason want to run you application in AKS, the explanation below is still valid.

## The TL;DR

All the steps are explained in bits and pieces somewhere, so I didn't invent any of the following and I'll cite my sources, but I want to give you a complete end-to-end picture. Follow the detailed steps below and you will see:

- How to create an Azure Kubernetes Service cluster with an attached [Azure Container Registry][acr] where the Spin application is [published and retrieved][oci] as an OCI artifact
- How to deploy SpinKube to tis cluster
- How to set up an Azure Cache for Redis instance and use it from the Spin application
- How to continuously build and deploy the Spin application using GitHub actions
- How to set up an Azure domain and then a custom domain to access the Azure Kubernetes cluster

If it's not a real production / business environment (where I would always use for a declarative IaC approach, preferably with GitOps), I like to use PowerShell to set up the infrastructure. It gives me the ability to iterate and change very quickly and it is also repeatable. Thanks to [PowerShell Core][pwsh], I can use it on both Windows and Linux, so it works wherever I need it. Therefore, the following steps are be done in PowerShell.

## The details: Naming and setup

First, we set up a number of variables for later use: Line 1 is the [Azure VM size][azure-vm] for the Kubernetes cluster nodes. Lines 2-4 are the [ID of the Azure subscription][az-sub], the name of the [Azure Resource Group][az-rg] and the [Azure location][az-loc] where all Azure resources are created. Lines 5-7 are the names for the Azure Container Registry, the Azure Cache for Redis and the name of the Azure domain to use. These are all derived from the other values, but you can change them if you like.

{% highlight powershell linenos %}
$vmSize = "Standard_B4ls_v2"
$subscriptionId = "94670b10-08d0-4d28-bcfe-e01f701cf9ff"
$rgAndClusterName = "verifiedbsky"
$location = "germanywestcentral"
$acrName = $rgAndClusterName.Replace("-", "")
$redisName = "redis-$rgAndClusterName"
$dns = "$($rgAndClusterName).$($location).cloudapp.azure.com"
{% endhighlight %}

With this in place, we can login (lines 1 and 2), set the subscription (line 4), add the required extension and providers (lines 5-7), and create the resource group (line 8):

{% highlight powershell linenos %}
az config set core.login_experience_v2=off
az login
az account set --subscription=$subscriptionId
az extension add --upgrade --name k8s-extension
az provider register --namespace Microsoft.ContainerService --wait 
az provider register --namespace Microsoft.KubernetesConfiguration --wait
az group create --name $rgAndClusterName --location $location
{% endhighlight %}

## The details: Azure Kubernetes Service

As mentioned above, in addition to the Kubernetes cluster, we also need a container/OCI artifact registry to share the Spin app with the cluster. The easiest way to set this up, while ensuring that the Kubernetes cluster has pull access, is to create the registry first and then attach it to the cluster when creating it. Hence the next steps where we create the registry in line 1, then the cluster in line 2, including the `--atach-acr` parameter to set up the connection between the cluster and the registry. In line 3, we get the [kube config][kubeconfig] for future `kubectl` commands to interact with the Kubernetes cluster:

{% highlight powershell linenos %}
az acr create --name $acrName --resource-group $rgAndClusterName --sku basic --admin-enabled true
az aks create -g $rgAndClusterName -n $rgAndClusterName --node-count 1 -s $vmSize --tier free --network-plugin azure --attach-acr $acrName --enable-app-routing --no-ssh-key
az aks get-credentials --resource-group $rgAndClusterName --name $rgAndClusterName --overwrite-existing
{% endhighlight %}

Later, for Continuous Deployment automation or manual tests, we will also need access credentials for the registry. We can retrieve this by getting the credentials (line 1) and storing them in variables (lines 2 and 3). For local testing, we can log in from Spin as in line 4 or just store them for later use:

{% highlight powershel linenos %}
$acrCreds = $(az acr credential show --name $acrName --resource-group $rgAndClusterName -ojson) | ConvertFrom-Json
$acruser = $acrCreds.username
$acrpwd = $acrCreds.passwords[0].value
spin registry login -u $acruser -p $acrpwd "$($acrname).azurecr.io"
{% endhighlight %}

After waiting for a while, we have a working, connected Azure Container Registry and Azure Kubernetes Service cluster.

The steps explained in this section are documented in the [Azure documentation][az-docs-aks] and in the [Spin documentation][spin-docs-reg].

## The details: SpinKube on the Kubernetes cluster

Since we want to run Spin applications on the cluster, we need to enable it for SpinKube. To do this, we again need some prerequisites: Lines 1 and 2 install the [Custom Resource Definitions][crds] and the [Runtime Class][rc]. Lines 3-5 add and update the [jetstack][jetstack] and [kwasm][kwasm] [helm][helm] repositories. Lines 6 and 7 then install [cert-manager][cert-manager], used by Spin internally and later to obtain Let's Encrypt certificates, and the kwasm [operator][operator], which will be used by the Spin operator later. Line 8 defines which nodes should get `containerd-wasm-shim` via kwasm.

{% highlight powershell linenos %}
kubectl apply -f https://github.com/spinkube/spin-operator/releases/download/v0.4.0/spin-operator.crds.yaml
kubectl apply -f https://github.com/spinkube/spin-operator/releases/download/v0.4.0/spin-operator.runtime-class.yaml
helm repo add jetstack https://charts.jetstack.io
helm repo add kwasm http://kwasm.sh/kwasm-operator/
helm repo update
helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --version v1.16.2 --set crds.enabled=true
helm install kwasm-operator kwasm/kwasm-operator --namespace kwasm --create-namespace --set kwasmOperator.installerImage=ghcr.io/spinkube/containerd-shim-spin/node-installer:v0.17.0
kubectl annotate node --all kwasm.sh/kwasm-node=true
{% endhighlight %}

The shim installation must be done before the next step. To find out if this has happened, we can simply check the operator logs with `kubectl logs -n kwasm -l app.kubernetes.io/name=kwasm-operator -f`. Once we see something like `{"level":"info","time":"2025-01-12T18:28:56Z","message":"Job aks-nodepool1-10327193-vmss000000-provision-kwasm is Completed. Happy WASMing"}`, we are ready for the next step.

The last two steps are to install the Spin operator and executor:

{% highlight powershell linenos %}
helm install spin-operator --namespace spin-operator --create-namespace --version 0.4.0 --wait oci://ghcr.io/spinkube/charts/spin-operator
kubectl apply -f https://github.com/spinkube/spin-operator/releases/download/v0.4.0/spin-operator.shim-executor.yaml
{% endhighlight %}

We are now ready to deploy Spin applications on the cluster.

The steps explained in this section are documented on the [Spin blog][spin-blog-redis].

## The details: Azure Cache for Redis

Setting up the Azure Cache for Redis is a one-liner: `az redis create -n $redisName -g $rgAndClusterName -l $location --sku Basic --vm-size c0 --redis-configuration '{ "maxmemory-policy": "noeviction" }'`. It may be worth noting that `maxmemory-policy` is set to `noeviction` as I use it more as a data store than a traditional cache. To set up access from Spin, we need a configuration file containing the URL with a password (technically an access key). We can do this with the following script, which retrieves  the information from Azure in line 1 and puts it into a file in the correct format:

{% highlight powershell linenos %}
@"
[key_value_store.default]
type = "redis"
url = "rediss://:$($redisKeys.primaryKey)@$redisName.redis.cache.windows.net:6380"
"@ | Out-File ./runtime-config-redis.toml
{% endhighlight %}

Assuming that you have a working Spin application that uses the integrated Key-Value store, such as [my Bluesky Verification tool][verifiedbsky] or the sample application documented [here][spin-kv-sample], all you need to do is reference that config file in your Spin command. E.g. `spin up --runtime-config-file runtime-config-redis.toml`. This should produce output like this to verify that the config file is being used:

{% highlight powershell linenos %}
Using runtime config [key_value_store.default: redis] from "runtime-config-redis.toml"
Logging component stdio to ".spin/logs/"
Storing default key-value data to Redis at redis-verifiedbsky.redis.cache.windows.net:6380.
{% endhighlight %}

The steps explained in this section are documented in the [Spin documentation][spin-docs-aks]. Note that whitelisting the outbound network connection for the Azure Cache for Redis, as explained in this blog post, is no longer required.

## The details: Continuous Deployment to Kubernetes using GitHub actions

Now we're ready to deploy, and could do this manually, but of course we want to do it continuously in an automated way, so let's get straight to it: The Spin CLI has a command that will help us scaffold the required file by using `spin kube scaffold -f $acrName.azurecr.io/verifiedbsky:v0.0.1 --runtime-config-file runtime-config-redis.toml -o spinapp.yaml`. As a result, we'll get a `spinapp.yaml` file that looks like this (with the secret invalidated out, of course)

{% highlight YAML linenos %}
apiVersion: core.spinkube.dev/v1alpha1
kind: SpinApp
metadata:
  name: verifiedbsky
spec:
  image: "whatever.azurecr.io/verifiedbsky:v0.0.1"
  executor: containerd-shim-spin
  replicas: 2
  runtimeConfig:
    loadFromSecret: verifiedbsky-runtime-config
---
apiVersion: v1
kind: Secret
metadata:
  name: verifiedbsky-runtime-config
type: Opaque
data:
  runtime-config.toml: W2tleV92YWx1ZV9zdG9yZS5kZWZhdWx0XQp0eXBlID0gInJlZGlzIgp1cmwgPSAicmVkaXNzOi8vOnNoc1c2aExoQUtSQXZEbEdTaUdBRzI1Y0pCaGhRTFdZcHNUZ0NhRTkyRWdzPUByZWRpcy12ZXJpZmllZGJza3kucmVkaXMuY2FjaGUud2luZG93cy5uZXQ6NjM4MCIK
{% endhighlight %}

Since the `SpinApp` will end up in our git repo, but the `Secret` definitely will not, we split them into two files: Lines 1-10 which describes the `SpinApp` stays in that file, lines 12-18 go into `secret.yaml`. With that in place, we create the secret in our cluster with `kubectl apply -f secret.yaml`. 

Deployment of the application can be set up in different ways, but my approach is basically to listen for version tags (which for me means tags starting with a "v") in a GitHub action and then trigger the deployment. I don't want to focus on the GitHub details in this blog post, but roughly you can see the trigger in lines 2-5, then checkout and setup in lines 15-27, Spin build and push to our container registry in lines 27-35 and deployment to the Kubernetes cluster in lines 42-45.

{% highlight yaml linenos %}
name: "Continuous Deployment"
on:
  push:
    tags:
    - 'v*' 
env:
  GO_VERSION: "1.23.2"
  TINYGO_VERSION: "v0.34.0"
  SPIN_VERSION: ""
jobs:
  spin:
    runs-on: "ubuntu-latest"
    name: Build Spin App
    steps:
      - uses: actions/checkout@v4
      - name: Install Go
        uses: actions/setup-go@v5
        with:
          go-version: "${{ env.GO_VERSION }}"
      - name: Install TinyGo
        uses: rajatjindal/setup-actions/tinygo@v0.0.1
        with:
          version: "${{ env.TINYGO_VERSION }}"
      - name: Install Spin
        uses: fermyon/actions/spin/setup@v1
        with:
          plugins: 
      - name: Build and push
        id: push
        uses: fermyon/actions/spin/push@v1
        with:
          registry: verifiedbsky.azurecr.io
          registry_username: ${{ secrets.ACR_USERNAME }}
          registry_password: ${{ secrets.ACR_PASSWORD }}
          registry_reference: "verifiedbsky.azurecr.io/verifiedbsky:${{ github.ref_name }}"
      - name: echo digest
        run: echo ${{ steps.push.outputs.digest }}
      - name: Kubectl config
        uses: actions-hub/kubectl@master
        env:
          KUBE_CONFIG: ${{ secrets.KUBE_CONFIG }}
      - name: Kubectl apply
        uses: actions-hub/kubectl@master
        with:
          args: apply -f spinapp.yaml
{% endhighlight %}
Note that the secrets in lines 33 and 34 are the values of the `$acruser` and `$acrpwd` variables we created in the "The details: Azure Kubernetes Service" section. Again, for a real business / production scenario, I would set this up differently with a GitOps based approach, but for my little side project, this is fine for me.

Now, if we create a tag `v0.0.1` in our repo and push it to GitHub, the action will be triggered, the Spin application will be built and pushed to the Azure Container registry and the application will be deployed to the Kubernetes cluster.

The (Spin) steps explained in this section are documented on the [SpinKube documentation][spinkube-cli].

## The details: Custom domain name and ingress

At the moment, our cluster is only accessible via an IP address, but of course we want to allow more human-friendly access. The easiest way to do this is to set the DNS label on the external IP for the Kubernetes cluster, which is automatically created when the cluster is set up. We first need to find the generated resource group (line 1), then get the external IP address connected to the also automatically generated load balancer called `kubernetes` (line 2), and set the DNS name (line 3).

{% highlight powershell linenos %}
$managedRgName = "MC_$($rgAndClusterName)_$($rgAndClusterName)_$($location)"
$frontendIPID = $( az network lb frontend-ip list --resource-group $managedRgName --lb-name "kubernetes" --query "[?loadBalancingRules!=null].name" --output tsv)
az network public-ip update --resource-group $managedRgName --name "kubernetes-$frontendIPID" --dns-name $rgAndClusterName
{% endhighlight %}

This enables us to reach our cluster via `<dns-label>.<location>.cloudapp.azure.com`, so in this example it would be `verifiedbsky.germanywestcentral.cloudapp.azure.com`. But at the moment, it can only handle HTTP traffic, because we haven't set up any HTTPS certificates. But as mentioned above, we already have `cert-manager` available, so we can use it to get [Let's Encrypt][le] certificates. First, we need a [ClusterIssuer][issuer], which is a representation of a certificate authority, in our case Let's Encrypt. Since Let's Encrypt has quite strict rate limits, it's highly advisable to work against their staging API first (more on that [here][le-staging]), but for the sake of brevity of this blog post, I'll show you the production issuer directly. Note that the `name` in line 4, which we'll need again in the next step, the `server` URL in line 7, which points to the Let's Encrypt production API and the `email` in line 8, which should be changed to yours.

{% highlight yaml linenos %}
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-production
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: tobias.fenster@notmydomain.de
    privateKeySecretRef:
      name: letsencrypt-production
    solvers:
      - http01:
          ingress:
            class: webapprouting.kubernetes.azure.com
            podTemplate:
              spec:
                nodeSelector:
                  "kubernetes.io/os": linux
{% endhighlight %}

After putting this into a file called `cluster-issuer.yaml`, we can bring it into our cluster with `kubectl apply -f cluster-issuer.yaml`. Now we can use the issuer to get a [certificate][cert] for our domain. Note the `secretName` in line 6, which we will need again in the next step, the `commonName` and `dnsNames` in lines 7-9, and the `name` and `kind` of the `issuerRef` in lines 10-12, which point to the `ClusterIssuer` we created in the last step.

{% highlight yaml linenos %}
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: www
spec:
  secretName: www-le
  commonName: verifiedbsky.germanywestcentral.cloudapp.azure.com
  dnsNames:
    -  verifiedbsky.germanywestcentral.cloudapp.azure.com
  issuerRef:
    name: letsencrypt-production
    kind: ClusterIssuer

{% endhighlight %}

The same works for a custom domain, you just need a new certificate with the custom domain instead of the .cloudapp.azure.com in the `commonName` and `dnsNames` lines of the certificate. You will also need to point the domain to the IP address of the public load balancer mentioned above. How this is set up depends on the company you bought it from, but basically you need an [A record][a-record] for your domain pointing to the IP address.

Now we've got our application and certificate in place, but we can't reach it easily yet. To do this, we need an [ingress][ingress], which in Kubernetes is the way to allow external requests (such as a browser accessing your application) to access a [service][service] in your cluster. In the SpinKube context, we automatically get a `service` based on the `SpinApp` configuration explained above, so all we need is the `ingress`. I have two of them, one for the generated domain name and one for the custom domain name. Note the `tls` sections in both lines 21-24 and 46-49 where we define the `hosts` and the `secretName` of the certificate. Also note that the `rules` also have the `host`, both in line 11 and 36. This is necessary as otherwise you may run into [this nginx ingress issue][nginx], which frustrated me for quite a while when setting this up.

{% highlight yaml linenos %}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: root
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$1
    nginx.ingress.kubernetes.io/use-regex: "true"
spec:
  ingressClassName: webapprouting.kubernetes.azure.com
  rules:
    - host: verifiedbsky.germanywestcentral.cloudapp.azure.com
      http:
        paths:
          - path: /(.*)
            pathType: Prefix
            backend:
              service:
                name: verifiedbsky
                port:
                  number: 80
  tls:
    - hosts:
        -  verifiedbsky.germanywestcentral.cloudapp.azure.com
      secretName: www-le
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: root-cust
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$1
    nginx.ingress.kubernetes.io/use-regex: "true"
spec:
  ingressClassName: webapprouting.kubernetes.azure.com
  rules:
    - host: verifiedbsky.net
      http:
        paths:
          - path: /(.*)
            pathType: Prefix
            backend:
              service:
                name: verifiedbsky
                port:
                  number: 80
  tls:
    - hosts:
        -  verifiedbsky.net
      secretName: www-le-cust
{% endhighlight %}

With that, we have everything in place: The `ingress` that routes our request to the `service`, which in turn points it to our `SpinApp`; the `Certificate` created by the `ClusterIssuer` to allow HTTPS traffic to work properly; the Spin application, which uses the Azure Cache for Redis as Key-Value store; and last but not least, SpinKube, which allows us to run the Spin application in the Azure Kubernetes Service cluster.

I hope this has given you an end-to-end idea of the whole setup and will help you if and when you try to come up with something similar!

The cert-manager / Let's Encrypt steps explained in this section are documented on the [cert-manager documentation][certmanager-docs].

[^1]: In the Fermyon Cloud, the Spin Key-Value store can only have a maximum of 1024 keys as documented [here][kv-limit]. Since the Bluesky verification tool already has close to 600 accounts as of 16.01.2025 and I store each of them in the k/v store, this limit will most likely be reached more or less quickly.

[fermyon-cloud]: https://www.fermyon.com/cloud
[fermyon]: https://www.fermyon.com/
[fermyon-spin]: https://www.fermyon.com/spin
[fermyon-spinkube]: https://www.spinkube.dev/
[kv-limit]: https://developer.fermyon.com/cloud/faq#quota-limits-key-value-maximum-keys
[vb]: https://verifiedbsky.net
[aks]: https://azure.microsoft.com/en-us/products/kubernetes-service
[azredis]: https://azure.microsoft.com/en-us/products/cache
[acr]: https://azure.microsoft.com/en-us/products/container-registry
[oci]: https://developer.fermyon.com/spin/v2/registry-tutorial#publishing-and-running-spin-applications-using-registries-video
[spin-kv]: https://developer.fermyon.com/spin/v2/key-value-store-tutorial
[pwsh]: https://github.com/PowerShell/PowerShell
[azure-vm]: https://learn.microsoft.com/en-us/azure/virtual-machines/sizes/overview
[az-sub]: https://learn.microsoft.com/en-us/azure/azure-portal/get-subscription-tenant-id
[az-rg]: https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/manage-resource-groups-portal
[az-loc]: https://learn.microsoft.com/en-us/azure/reliability/availability-zones-overview?tabs=azure-cli
[kubeconfig]: https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/
[az-docs-aks]: https://learn.microsoft.com/en-us/azure/aks/cluster-container-registry-integration?tabs=azure-cli
[spin-docs-reg]: https://developer.fermyon.com/spin/v2/registry-tutorial
[crds]: https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definitions/
[rc]: https://kubernetes.io/docs/concepts/containers/runtime-class/
[jetstack]: https://jetstack.io
[kwasm]: https://kwasm.sh/
[helm]: https://helm.sh/
[cert-manager]: https://cert-manager.io/
[operator]: https://kubernetes.io/docs/concepts/extend-kubernetes/operator/
[spin-docs-aks]:https://www.spinkube.dev/docs/install/azure-kubernetes-service/
[spin-blog-redis]: https://www.fermyon.com/blog/azure-cache-for-redis-as-key-value-store-with-spinkube
[spin-kv-sample]: https://developer.fermyon.com/spin/v2/key-value-store-tutorial
[verifiedbsky]: /verifying-user-accounts-on-bluesky-with-a-wasm-spin-application
[spinkube-cli]: https://www.spinkube.dev/docs/topics/packaging/
[ingress]: https://kubernetes.io/docs/concepts/services-networking/ingress/
[service]: https://kubernetes.io/docs/concepts/services-networking/service/
[le]: https://letsencrypt.org/
[certmanager-docs]: https://cert-manager.io/docs/tutorials/acme/nginx-ingress/
[issuer]: https://cert-manager.io/docs/concepts/issuer/
[le-staging]: https://cert-manager.io/docs/tutorials/acme/nginx-ingress/#step-6---configure-a-lets-encrypt-issuer
[cert]: https://cert-manager.io/docs/usage/certificate/
[a-record]: https://www.cloudflare.com/learning/dns/dns-records/dns-a-record/
[nginx]: https://github.com/kubernetes/ingress-nginx/issues/7153#issuecomment-859254337