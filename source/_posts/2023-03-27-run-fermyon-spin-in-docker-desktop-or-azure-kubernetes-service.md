---
layout: post
title: "Run Fermyon Spin in Docker Desktop or Azure Kubernetes Service"
permalink: run-fermyon-spin-in-docker-desktop-or-azure-kubernetes-service
date: 2023-03-27 18:55:58
comments: false
description: "Run Fermyon Spin in Docker Desktop or Azure Kubernetes Service"
keywords: ""
image: /images/spin-on-aks-dd.png
categories:

tags:

---

I have previously shared my little [Fermyon Spin][spin] tool to [duplicate planner plans with adjustments][spin1] and the [Blazor frontend][spin2] for it. What I haven't shared yet is a good way how to deploy both components together. I have briefly touched on [Spin deployment options][deployment] and depending on your needs, those are certainly great, but I wanted something that allowed me to deploy both backend and frontend together. I had tinkered with both [AKS][aks] and [Docker Desktop][dd] without success, but because two things changed, it finally worked.

## The TL;DR

The easier option is to run both services containerized in Docker Desktop. Why this wasn't possible until recently can be found in the details, but if you don't care and just want to give it a try, here are the steps:

1. Download, install and run the [Docker+Wasm Technical Preview 2][dwtp2]. Make sure to activate the containerd image store (Settings > Features in development > Use containerd). This is the first of the two things I mentioned that has changed, and it allows very easy local use of Spin.
2. Download the [Docker compose][dc] file [here][my-dc] and fill in values for client ID, tenant ID and client secret for an app registration with web platform, `Group.ReadWrite.All`, `User.ReadBasic.All`, `openid` and `profile` permissions, and a `https://localhost/authentication/login-callback` redirect URI. Again, if you don't know what that is, see below.
3. Run `docker compose up`. This should give you an output like
{% highlight powershell linenos %}
[+] Running 2/13
 - backend Pulled                                                                                                                                                                                                      8.6s
   - 811366cf4bc4 Download complete                                                                                                                                                                                   11.3s
   - 5618b820e384 Download complete                                                                                                                                                                                   10.4s
   - 7b28b870dad6 Download complete                                                                                                                                                                                    8.1s
   - 74866baf44e7 Download complete                                                                                                                                                                                    8.1s
 - frontend Pulled                                                                                                                                                                                                    14.9s
   - 3885bb4c9b94 Download complete                                                                                                                                                                                   11.4s
   - 8e6da25b991c Download complete                                                                                                                                                                                   10.5s
   - 4f4fb700ef54 Exists                                                                                                                                                                                               8.2s
   - 2e21560b57d2 Download complete                                                                                                                                                                                    8.1s
   - f46fafcc88dd Download complete                                                                                                                                                                                    8.1s
   - b9e09030ad8e Download complete                                                                                                                                                                                    8.1s
   - 4726e5aac983 Download complete                                                                                                                                                                                    8.1s
[+] Running 3/3
 - Network demo_default       Created                                                                                                                                                                              0.1s
 - Container demo-backend-1   Created                                                                                                                                                                              0.7s
 - Container demo-frontend-1  Created                                                                                                                                                                              0.1s
Attaching to demo-backend-1, demo-frontend-1
demo-frontend-1  | warn: Microsoft.AspNetCore.DataProtection.Repositories.FileSystemXmlRepository[60]
demo-frontend-1  |       Storing keys in a directory '/app/.aspnet/DataProtection-Keys' that may not be persisted outside of the container. Protected data will be unavailable when container is destroyed.
demo-frontend-1  | warn: Microsoft.AspNetCore.DataProtection.KeyManagement.XmlKeyManager[35]
demo-frontend-1  |       No XML encryptor configured. Key {bf5a4f76-ecab-45bf-9e42-a1f1939eec10} may be persisted to storage in unencrypted form.
demo-frontend-1  | warn: Microsoft.AspNetCore.Server.Kestrel.Core.KestrelServer[8]
demo-frontend-1  |       The ASP.NET Core developer certificate is not trusted. For information about trusting the ASP.NET Core developer certificate, see https://aka.ms/aspnet/https-trust-dev-cert.
demo-frontend-1  | info: Microsoft.Hosting.Lifetime[14]
demo-frontend-1  |       Now listening on: http://[::]:80
demo-frontend-1  | info: Microsoft.Hosting.Lifetime[14]
demo-frontend-1  |       Now listening on: https://[::]:443
demo-frontend-1  | info: Microsoft.Hosting.Lifetime[0]
demo-frontend-1  |       Application started. Press Ctrl+C to shut down.
demo-frontend-1  | info: Microsoft.Hosting.Lifetime[0]
demo-frontend-1  |       Hosting environment: Production
demo-frontend-1  | info: Microsoft.Hosting.Lifetime[0]
demo-frontend-1  |       Content root path: /app
{% endhighlight %}

Then, go to [https://localhost:3001](https://localhost:3001), accept the development certificate and you should see the Blazor frontend while the backend also is already running.

![Blazor frontend in a local browser](/images/spin-in-dd.png)
{: .centered}

If you try this yourself, you should see how extemely fast the images are pulled and started, in my case in about 20 seconds. This is possible because the Spin / Wasm based image for the backend is insanely small (7.31 MB) and the Blazor based image for the frontend is not bad either (72.08 MB). And [Docker Scout][scout] tells me that they have no vulnerabilities, so what's not to like :) If you want, you can get the full sources [here][src].

Now, let's dive into the details:

## The details: Prerequisite 1 - an app registration

As I mentioned above, we need an app registration, which is basically the representation of an application to Azure AD for identity purposes. If you want to learn more, check out [the docs][appreg]. We want to use it to read and write groups, read user information and to provide Single-Sign-On capabilities. You can do this manually in the Azure Portal as [explained here][create-appreg], but I prefer to run a script and thanks to [this blog post][m365-cli] by [Luise Freese][luise] (thanks!) about the CLI for Microsoft 365, it's pretty easy. If you already have [Node.js][node] and [npm][npm] installed locally, you can just go ahead and [install it][cli-install], but I'm trying to keep my laptop and dev environments more or less clean, so let's [do this in a container][cli-docker]. To do that, we run `docker run --rm -it m365pnp/cli-microsoft365:latest` and when that finishes downloading and starting, we should be in an interactive session in the container:

{% highlight powershell linenos %}
PS C:\Users\tfenster> docker run --rm -it m365pnp/cli-microsoft365:latest
Unable to find image 'm365pnp/cli-microsoft365:latest' locally
5ea5152ee01b: Download complete
f8de924f8f70: Download complete
4f4fb700ef54: Exists
fd5290cd991c: Download complete
4dfa733cb69c: Download complete
20e2720222a5: Download complete
8572bc8fb8a3: Download complete
821fbb9cdd43: Download complete
4c83eedd2c9b: Download complete
eba1493833f6: Download complete
a3836c9042bc:~$
{% endhighlight %}

Now we can easily log in using the default device code flow by simply calling `m365 login` and after following the instructions, we are logged in. Then we call the command to create the app registration (`m365 aad app add ...`) and we get the information we need: the appId aka clientId, the tenantId and the value of a secret (all entries redacted):

{% highlight powershell linenos %}
a3836c9042bc:~$ m365 login
"To sign in, use a web browser to open the page https://microsoft.com/devicelogin and enter the code DRVTTNPVB to authenticate."
a3836c9042bc:~$ m365 aad app add --name 'Planner duplication' --redirectUris 'https://localhost/authentication/login-callback,http://localhost/authentication/login-callback' --platform web --withSecret --apisDelegated 'https://graph.microsoft.com/Group.ReadWrite.All,https://graph.microsoft.com/User.ReadBasic.All,https://graph.microsoft.com/openid,https://graph.microsoft.com/profile' --grantAdminConsent
{
  "appId": "a5041219-ce8b-4ad9-b919-aaf3bb755b0b",
  "objectId": "7ed3d89a-92c2-438a-a6c0-671f3b914496",
  "tenantId": "539f23a2-6819-457e-bd87-7835f4122217",
  "secrets": [
    {
      "displayName": "Default",
      "value": "6TB8Q~syQEqzwaX50u8zDDPoMPweOIrGTUmYXdzs"
    }
  ]
}
{% endhighlight %}

Keep thiss information, we will need it later. Also, keep the container session open if you want to deploy to AKS, because we will need to make another call.

## The details: Prerequisite 2 - container images

Definitely to deploy to AKS and also to run it in Docker Desktop the easy way, we need container images. For the Blazor-based frontend this is relatively easy (trimming requires [manual work][trim]):

{% highlight Dockerfile linenos %}
FROM mcr.microsoft.com/dotnet/sdk:7.0-alpine AS build

WORKDIR /src/shared
COPY ./shared/shared.csproj .
WORKDIR /src
RUN dotnet restore "shared/shared.csproj" -r alpine-x64 /p:PublishReadyToRun=true

WORKDIR /src/frontend
COPY ./frontend/frontend.csproj .
WORKDIR /src
RUN dotnet restore "frontend/frontend.csproj" -r alpine-x64 /p:PublishReadyToRun=true

WORKDIR /src/
COPY ./frontend/ ./frontend/
COPY ./shared/ ./shared/

WORKDIR /src/frontend
RUN dotnet publish --no-restore -c Release -r alpine-x64 -o /app/publish /p:PublishReadyToRun=true /p:PublishSingleFile=true --self-contained true

RUN dotnet dev-certs https

FROM mcr.microsoft.com/dotnet/runtime-deps:7.0-alpine AS final
EXPOSE 80 443
ENV ASPNETCORE_URLS=http://+:80;https://+:443
ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false

COPY --from=build /root/.dotnet/corefx/cryptography/x509stores/my/* /app/.dotnet/corefx/cryptography/x509stores/my/

RUN apk add --no-cache icu-libs

RUN adduser --disabled-password --home /app --gecos '' nonroot && chown -R nonroot /app
USER nonroot

WORKDIR /app
COPY --from=build /app/publish .

ENTRYPOINT ["./frontend"]
{% endhighlight %}

First, we define the `build` stage based on the .NET SDK image, copy in the `.csproj` files and restore (lines 1-11). Then we copy in all the sources and publish them in an optimized way (lines 13-18). As we will see later, we need to use https, so we also create self-signed dev certificates in the `build` stage since we have the full SDK here (line 20). With that in place, we go to the `final` stage, based on the .NET runtime dependencies image (line 22), expose ports, define them for .NET (lines 23 and 24) and define the `DOTNET_SYSTEM_GLOBALIZATION_INVARIANT` as `false` (line 25), otherwise Blazor will fail. Then we add the dev certs mentioned above (line 27), install `icu-libs` (line 29) as another Blazor requirement and switch to a non-root user called `nonroot` (lines 31 and 32). Finally, we copy the publish results from the `build` stage and set the entrypoint to the generated self-contained single file (line 37).

The Spin / Wasm backend is a kind of similar, but especially the final stage is different:

{% highlight Dockerfile linenos %}
FROM --platform=${BUILDPLATFORM} mcr.microsoft.com/dotnet/sdk:7.0 AS build
WORKDIR /opt/build

RUN apt update && apt install -y build-essential && curl -fsSL https://sh.rustup.rs | bash -s -- -y && export PATH=$PATH:$HOME/.cargo/bin && rustup default stable && cargo install wizer --all-features
RUN curl -fsSL https://developer.fermyon.com/downloads/install.sh | bash && mv spin /usr/local/bin/

WORKDIR /opt/build/shared
COPY ./shared/shared.csproj .
RUN dotnet restore

WORKDIR /opt/build/backend
COPY ./backend/Project.csproj .
RUN dotnet restore

WORKDIR /opt/build/
COPY . .

WORKDIR /opt/build/backend
RUN PATH=$PATH:$HOME/.cargo/bin spin build

FROM scratch
COPY --from=build /opt/build/backend/bin/Release/net7.0/planner_exandimport_wasm.wasm .
COPY --from=build /opt/build/backend/spin.toml.container ./spin.toml
ENTRYPOINT [ "/planner_exandimport_wasm.wasm" ]
{% endhighlight %}

Again, we define a `build` stage with the .NET SDK and go to a build folder (lines 1 and 2). We then use [rustup][rustup] to install the [Rust][rust] language and its package manager [Cargo][cargo], and then use Cargo to install [Wizer][wizer], which completes the toolchain for Spin (line 4). With that in place, we download and install Spin (line 5). Following the best-practice structure for containerized .NET builds, we copy `.csproj` and restore (lines 7-13), then copy in all sources (lines 15 and 16) and use `spin build` (line 19) to create a Wasm module. Then we go to the final stage based on an empty image (line 21), copy in the created Wasm module and config file (lines 22 and 23), and set the entrypoint to the module (line 24).

## The details: Running it in Docker Desktop - the hard way

Now we can use the `docker-compose.build.yml` from my repo to build and run the container images:

{% highlight yaml linenos %}
version: "3.9"
services:
  backend:
    build: 
      context: .
      dockerfile: Dockerfile.backend
    runtime: io.containerd.spin.v1
  frontend:
    build: 
      context: .
      dockerfile: Dockerfile.frontend
    environment:
      - BackendBaseUrl=http://backend:80
      - AzureAd__ClientId=...
      - AzureAd__TenantId=...
      - AzureAd__ClientSecret=...
    ports:
      - "3000:80"
      - "3001:443"
    depends_on:
      - backend
{% endhighlight %}

In lines 4-6 and 9-11 you can see that we are telling Docker to use the correct Dockerfiles for the backend (Spin / Wasm) and frontend (Blazor) container images. Notice in line 7 that the `io.containerd.spin.v1` runtime is referenced. This is the reason why you needed to install the technical preview mentioned above, because this preview brings support for this particular runtime (and others). To learn more, read the [announcement on the Docker blog][announce]. You also need to set up the `AzureAd__ClientId`, `AzureAd__TenantId` and `AzureAd__ClientSecret` with the information that we got from the M365 CLI call explained above. Next, you can run a `docker compose -f docker-compose.build.yaml up` to ask Docker to run the image builds and start the containers as configured. After that, you can go to [https://localhost:3001](https://localhost:3001), accept the self-signed certificates and you should be goof to go! Note that installing the Spin toolchain takes a while, so it will probably take a few minutes to build the backend image in particular.

## The details: Running it in Docker Desktop - the easy way

If you don't want to wait for the image to build, you can also use the `docker-compose.yml` from my repo to run pre-built container images:

{% highlight yaml linenos %}
version: "3.9"
services:
  backend:
    image: tobiasfenster/planner-exandimport-wasm-backend:latest
    runtime: io.containerd.spin.v1
  frontend:
    image: tobiasfenster/planner-exandimport-wasm-frontend:latest
    environment:
      - BackendBaseUrl=http://backend:80
      - AzureAd__ClientId=...
      - AzureAd__TenantId=...
      - AzureAd__ClientSecret=...
    ports:
      - "3000:80"
      - "3001:443"
    depends_on:
      - backend
{% endhighlight %}

Basically the same as above, but instead of the build instructions mentioned above, only the images are referenced in lines 4 and 7. You also need to set up the `AzureAd__ClientId`, `AzureAd__TenantId` and `AzureAd__ClientSecret` with the information that we got from the M365 CLI call explained above and run `docker compose up` (it will take the default `docker-compose.yaml` as config file), but this time it will just pull the very small images and start, so it will be much faster than before. After that, you can again go to [https://localhost:3001](https://localhost:3001), accept the self-signed certificates and the Blazor frontend should greet you!

## The details: Deploying it to the Azure Kubernetes Service

While Docker Desktop is certainly a great way to get the two components up and running in almost no time for you, it's not the right way if you want to share the application with others and keep it running when your laptop isn't. Of course, there are many different options to achieve this, but I decided to use the Azure Kubernetes Service (AKS). It brought some Spin / Wasm support earlier, but not completely. Thanks to [Kwasm][kwasm], a [Kubernetes operator][koperator] that brings support for Spin (and others) to any Kubernetes distribution or provider, you can make if work completely (which is the second thing that changed recently) and this is the way to do it. I'm assuming you have an Azure subscription and are running the following commands in an [Azure Cloud Shell][azcshell].

The first step is to deploy an AKS cluster based on the official [docs][aks-docs]:

{% highlight bash linenos %}
location=northeurope
rg=aks-spin
clustername=aks-spin

az group create --name $rg --location $location
az aks create -g $rg -n $clustername --enable-managed-identity --node-count 1 --enable-addons monitoring --enable-msi-auth-for-monitoring  --generate-ssh-keys
az aks get-credentials --resource-group $rg --name $clustername

kubectl get nodes

kubectl create namespace planner-wasm
{% endhighlight %}

In the first three lines, we set some variables for later use. If we want a different Azure region (`location`), resource group name (`rg`) or Kubernetes cluster name (`clustername`), we can change all of them. Then we create the resource group (line 5), the AKS cluster (line 6) and get the access credentials (line 7). To validate that everything is in place, we check the nodes (line 9). Finally, we create a [namespace][namespace] (line 11), a mechanism in Kubernetes for isolating and grouping resources.

The second step is to deploy Kwasm to our AKS cluster:

{% highlight bash linenos %}
helm repo add kwasm http://kwasm.sh/kwasm-operator/
helm repo update
helm install -n kwasm --create-namespace kwasm-operator kwasm/kwasm-operator
kubectl annotate node --all kwasm.sh/kwasm-node=true
{% endhighlight %}

This adds the Kwasm helm chart repository (line 1), updates it (line 2), and installs the Kwasm operator (line 3). It then annotates all nodes as Kwasm nodes (line 4), so that Wasm (and in our case Spin) workloads can run on them. We also need to deploy the [Kubernetes Runtime Class][runtime-class] for Spin with the corresponding handler. For that, create a file called `runtime.yaml` with the following content

{% highlight yaml linenos %}
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: wasmtime-spin
handler: spin
{% endhighlight %}

and deploy it with `kubectl apply -f runtime.yaml`.

Now that Kwasm is ready, the next step is to deploy our workload, which is the frontend and backend for my Planner plan duplication tool. The frontend is just a regular container image, so that would have worked out of the box, but the backend is Spin / Wasm, so we needed the Kwasm operator and runtime. Create a `workload.yaml` file with the following content:

{% highlight yaml linenos %}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: frontend
        image: tobiasfenster/planner-exandimport-wasm-frontend:v0.1.0
        env:
        - name: BackendBaseUrl
          value: "http://backend:80"
        - name: AzureAd__ClientId
          value: "..."
        - name: AzureAd__TenantId
          value: "..."
        - name: AzureAd__ClientSecret
          value: "..."
        - name: ASPNETCORE_URLS
          value: http://+:8080
        - name: ASPNETCORE_FORWARDEDHEADERS_ENABLED
          value: "true"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      runtimeClassName: wasmtime-spin
      containers:
      - name: backend
        image: tobiasfenster/planner-exandimport-wasm-backend:v0.1.0
---
apiVersion: v1
kind: Service
metadata:
  name: frontend
spec:
  type: ClusterIP
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080
      name: "http"
  selector:
    app: frontend
---
apiVersion: v1
kind: Service
metadata:
  name: backend
spec:
  type: ClusterIP
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
      name: "http"
  selector:
    app: backend
{% endhighlight %}

You can see two [Kubernetes deployments][deployment] (the way you tell Kubernetes which containerized workloads you want to run), and two [Kubernetes Services][service] (the network configuration for your workloads). The first deployment (lines 1-30) defines the frontend, and the second deployment (lines 32-49) defines the backend. Of note are the Azure AD configuration fields that you know by now (lines 21-26), the `ASPNETCORE_FORWARDEDHEADERS_ENABLED` env variable set to `true` (lines 29 and 30, took me a loooong night to figure out), and the reference to the Kwasm runtime class for Spin that we deployed above (line 46). To make the backend available from the frontend, we define the backend service (lines 65-77) and to make the frontend available in the cluster, we define the frontend service (lines 51-63). With that done, you can run `kubectl apply -f workload.yaml --namespace planner-wasm` to trigger the actual deployment. If you want to track the progess, run `kubectl get pods --namespace planner-wasm` until all have status ready and `kubectl get svc --namespace planner-wasm` until all have a cluster IP.

The fourth big step is to define the [Kubernetes Ingress][ingress], which defines external network availability of the resources in your Kubernetes cluster. Again, I have based this on the [official AKS docs][ingress-docs] with a few tweaks. We want to reach our frontend with a valid SSL certificate and a nice DNS name, so first of all, we need to set the DNS label to something unique, like `dnslabel=abj789tfe`. Then we get the automatically created resource group containing all the technical resources for our AKS cluster and use it to create a public IP address for our cluster with 

{% highlight bash linenos %}
clusterrg=$(az aks show --resource-group $rg --name $clustername --query nodeResourceGroup -o tsv)
publicIp=$(az network public-ip create --resource-group $clusterrg --name myAKSPublicIP --sku Standard --allocation-method static --query publicIp.ipAddress -o tsv)
{% endhighlight %}

Then we add the helm chart repo for `ingress-nginx`, as the name says an [Nginx][nginx] based ingress, update it and install the `ingress-nginx` repo

{% highlight bash linenos %}
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-dns-label-name"=$dnslabel --set controller.service.loadBalancerIP=$publicIp --namespace planner-wasm
{% endhighlight %}

This takes care of external availability, but we also need the right certificate for https to work properly. For this we use the [Jetstack cert-manager][jetstack]:

{% highlight bash linenos %}
kubectl label namespace planner-wasm cert-manager.io/disable-validation=true
helm repo add jetstack https://charts.jetstack.io
helm repo update
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.7.1/cert-manager.crds.yaml
helm install cert-manager jetstack/cert-manager --version v1.7.1 --namespace planner-wasm
{% endhighlight %}

Again we add and update the helm chart repo (lines 2 and 3), then we bring in some [Kubernetes Custom Resource Definitions][crds] (line 4, a way to extend Kubernetes) and install the cert-manager chart (line 5). We'll use this in a `ClusterIssuer`, which defines how and from where our certificates will be issued. Create a `cluster-issuer.yaml` file with the following content

{% highlight yaml linenos %}
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: tfenster@4psbau.de
    privateKeySecretRef:
      name: letsencrypt
    solvers:
    - http01:
        ingress:
          class: nginx
          podTemplate:
            spec:
              nodeSelector:
                "kubernetes.io/os": linux
{% endhighlight %}

Of course, you need to change the email address in line 8. And you can see that we're using [Let's Encrypt][le] as external service to get the certificates. To get this definition into your cluster, run `kubectl apply -f cluster-issuer.yaml --namespace planner-wasm`. 

Now we have our workload, the ingress resources to allow external network access and the cert-manager to help with the https certificates. Now we bring it all together with the `Ingress` definition itself. Again, create a file, this time called `ingress.yaml` with the following content:

{% highlight yaml linenos %}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hello-world-ingress
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt
spec:
  tls:
  - hosts:
    - abj789tfe.northeurope.cloudapp.azure.com
    secretName: tls-secret
  rules:
  - host: abj789tfe.northeurope.cloudapp.azure.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend
            port:
              number: 80
{% endhighlight %}

Make sure to change the urls in lines 11 and 14 to your DNS label and Azure region and then deploy with `kubectl apply -f ingress.yaml --namespace planner-wasm`. You can see the ingress class referenced in line 6 and the cluster issuer in line 7. The TLS host in line 11 triggers the retrieval of a certificate, which is stored in the secret defined in line 12. Finally, the rule in lines 14-23 defines how our frontend is reachable. You can run `kubectl get certificate --namespace planner-wasm -w` and wait until `READY` becomes `true`, which means that the certificate has been retrieved from Let's encrypt and stored in the secret. 

Now we can access the frontend through the https URL with a proper certificate. But when the Single-Sign-On returns, it will complain about a bad redirect URL, but we can fix that with our M365 CLI container. Go back and run the following command, of course with your object ID as returned by the previous command and the correct redirect URL for your DNS labe and Azure region

{% highlight bash linenos %}
m365 aad app set --objectId 7ed3d89a-92c2-438a-a6c0-671f3b914496 --redirectUris https://abf789tfe.northeurope.cloudapp.azure.com/authentication/login-callback --platform web
{% endhighlight %}

Make sure to use the object ID, not the app / client ID. I may or may not have mixed them up and wondered for quite a while what went wrong...

Now, finally, you can go to [https://abf789tfe.northeurope.cloudapp.azure.com/](https://abf789tfe.northeurope.cloudapp.azure.com/) and access the Blazor frontend, which in turn calls the Spin / Wasm backend, all running on an AKS cluster. Nice, right?

If you don't need all of this anymore, you can run `az group delete --name $rg --yes --no-wait`. Be careful, this doesn't ask for confirmation, it just deletes everything.

I hope I have given you an idea of how you can use Docker Desktop and AKS to run your Spin / Wasm and "normal" container workloads side by side!

[spin1]: https://tobiasfenster.io/net-in-webassembly-with-fermyon-spin-or-how-to-duplicate-your-planner-plans-with-adjustments
[spin2]: https://tobiasfenster.io/a-blazor-frontend-for-the-webassembly-planner-duplication-tool-running-on-fermyon-spin
[spin]: https://www.fermyon.com/spin
[deployment]: https://tobiasfenster.io/a-blazor-frontend-for-the-webassembly-planner-duplication-tool-running-on-fermyon-spin#the-details-deployment-and-what-i-learned-again-about-fermyon-spin
[aks]: https://azure.microsoft.com/en-us/products/kubernetes-service
[dd]: https://www.docker.com/products/docker-desktop/
[dwtp2]: https://www.docker.com/blog/announcing-dockerwasm-technical-preview-2/
[my-dc]: https://raw.githubusercontent.com/tfenster/planner-exandimport-wasm/master/docker-compose.yml
[dc]: https://docs.docker.com/compose/
[scout]: https://www.docker.com/products/docker-scout/
[appreg]: https://learn.microsoft.com/en-us/azure/active-directory/develop/app-objects-and-service-principals
[create-appreg]: https://learn.microsoft.com/en-us/azure/active-directory/develop/quickstart-register-app
[m365-cli]: https://www.m365princess.com/blogs/cli-microsoft-365-power-platform/
[luise]: https://www.m365princess.com/about/
[node]: https://nodejs.org/en
[npm]: https://www.npmjs.com/
[cli-install]: https://pnp.github.io/cli-microsoft365/user-guide/installing-cli/
[cli-docker]: https://pnp.github.io/cli-microsoft365/user-guide/run-cli-in-docker-container/
[trim]: https://learn.microsoft.com/en-us/aspnet/core/blazor/host-and-deploy/configure-trimmer?view=aspnetcore-7.0
[src]: https://github.com/tfenster/planner-exandimport-wasm
[rust]: https://www.rust-lang.org/
[cargo]: https://doc.rust-lang.org/cargo/
[rustup]: https://rustup.rs/
[wizer]: https://crates.io/crates/wizer
[announce]: https://www.docker.com/blog/announcing-dockerwasm-technical-preview-2/
[kwasm]: https://kwasm.sh
[koperator]: https://kubernetes.io/docs/concepts/extend-kubernetes/operator/
[azcshell]: https://learn.microsoft.com/en-us/azure/cloud-shell/overview
[aks-docs]: https://learn.microsoft.com/en-us/azure/aks/learn/quick-kubernetes-deploy-cli
[namespace]: https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/
[deployment]: https://kubernetes.io/docs/concepts/workloads/controllers/deployment/
[runtime-class]: https://kubernetes.io/docs/concepts/containers/runtime-class/
[service]: https://kubernetes.io/docs/concepts/services-networking/service/
[ingress]: https://kubernetes.io/docs/concepts/services-networking/ingress/
[ingress-docs]: https://learn.microsoft.com/en-us/azure/aks/ingress-basic?tabs=azure-cli
[nginx]: https://www.nginx.com/
[jetstack]: https://www.jetstack.io/open-source/cert-manager/
[crds]: https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/#customresourcedefinitions
[le]: https://letsencrypt.org/