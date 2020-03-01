---
layout: page
title: "6 Dockerfiles"
description: ""
keywords: ""
permalink: "cosmo-docker-6-dockerfiles"
slug: "cosmo-docker-6-dockerfiles"
---
{::options parse_block_html="true" /}
Table of content
- [Create an Apache web server image](#create-an-apache-web-server-image)
- [Create an image by building a custom solution](#create-an-image-by-building-a-custom-solution)
- [Use a multi-stage image](#use-a-multi-stage-image)

&nbsp;<br />

### Create an Apache web server image
In this lab we will create an image for the popular open source web server Apache. The installation process is very simple: We download a .zip file and expand it and install the neccessary .NET prerequisite library. Check the [Dockerfile](https://github.com/tfenster/presentation-src/blob/cosmo-docker/apache-httpd/Dockerfile) to get the details. The sources have been downloaded to your host VM already, so you can just run the following steps to build your image and run a container:
```bash
cd c:\sources\presentation-src-cosmo-docker\apache-httpd\
docker build -t myapache .
docker run -p 80:80 --name apache myapache
```

<details><summary markdown="span">Full output of details</summary>
```bash
PS C:\> cd c:\sources\presentation-src-cosmo-docker\apache-httpd\
PS c:\sources\presentation-src-cosmo-docker\apache-httpd> docker build -t myapache .
Sending build context to Docker daemon  3.584kB
Step 1/7 : FROM mcr.microsoft.com/windows/servercore:ltsc2019
ltsc2019: Pulling from windows/servercore
65014b3c3121: Already exists
12c8dbabfd62: Already exists
Digest: sha256:404e0ee336a063619d1e93a2446061cf19cb3068bacb1775f5613e3b54e527e1
Status: Downloaded newer image for mcr.microsoft.com/windows/servercore:ltsc2019
 ---> 739b21bd02e7
Step 2/7 : SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]
 ---> Running in b50c6ee51a4a
Removing intermediate container b50c6ee51a4a
 ---> f77628a83cb4
Step 3/7 : ENV APACHE_VERSION 2.4.41
 ---> Running in 0b75df9a4766
Removing intermediate container 0b75df9a4766
 ---> 6d8750c277fa
Step 4/7 : RUN Invoke-WebRequest ('http://de.apachehaus.com/downloads/httpd-{0}-o111c-x64-vc15-r2.zip' -f $env:APACHE_VERSION) -OutFile 'apache.zip' -UseBasicParsing ;     Expand-Archive apache.zip -DestinationPath C:\ ;     Remove-Item -Path apache.zip
 ---> Running in e10c2d6f015f
Removing intermediate container e10c2d6f015f
 ---> 4afbd51e217d
Step 5/7 : RUN Invoke-WebRequest 'https://download.microsoft.com/download/9/3/F/93FCF1E7-E6A4-478B-96E7-D4B285925B00/vc_redist.x64.exe' -OutFile 'vc_redist.x64.exe';     Start-Process '.\vc_redist.x64.exe' '/install /passive /norestart' -Wait;     Remove-Item vc_redist.x64.exe;
 ---> Running in 66c18eaa7a49
Removing intermediate container 66c18eaa7a49
 ---> a1ef91274853
Step 6/7 : EXPOSE 80
 ---> Running in 2160d265fb02
Removing intermediate container 2160d265fb02
 ---> f9ac1f559e3c
Step 7/7 : CMD [ "C:\\Apache24\\bin\\httpd.exe" ]
 ---> Running in 911f2692e61b
Removing intermediate container 911f2692e61b
 ---> 6e9ba57f7698
Successfully built 6e9ba57f7698
Successfully tagged myapache:latest
PS c:\sources\presentation-src-cosmo-docker\apache-httpd> docker run -p 80:80 --name apache myapache

```
</details>
&nbsp;<br />
Go to [http://localhost](http://localhost) to see the Apache start page. 
Make sure you remove the container in the end with `docker rm -f apache`
&nbsp;<br />

### Create an image by building a custom solution 
The second scenario is one where we have the sources because the application is open source or built in-house. To make sure that we have a standardized build process, we put that in the image as well. Check the [Dockerfile](https://github.com/tfenster/presentation-src/blob/cosmo-docker/webapp/Dockerfile) to see the details. To run that particular build and then the container, do the following:
```bash
cd c:\sources\presentation-src-cosmo-docker\webapp\
docker build -t mywebapp .
docker run -p 80:80 --name webapp mywebapp
```

<details><summary markdown="span">Full output of the build and run commands</summary>
```bash
PS C:\Users\CosmoAdmin\Desktop> cd c:\sources\presentation-src-cosmo-docker\webapp\
PS c:\sources\presentation-src-cosmo-docker\webapp> docker build -t mywebapp .
Sending build context to Docker daemon  65.54kB
Step 1/10 : FROM mcr.microsoft.com/dotnet/core/sdk:2.2-nanoserver-1809 AS build
 ---> 3e706675d42e
Step 2/10 : EXPOSE 80
 ---> Running in e32952db2cb0
Removing intermediate container e32952db2cb0
 ---> a52bb3cec310
Step 3/10 : WORKDIR /src
 ---> Running in 05a92eba0fd5
Removing intermediate container 05a92eba0fd5
 ---> 86efb81c79a6
Step 4/10 : COPY ["webapp.csproj", "./"]
 ---> cd83f2e93dbe
Step 5/10 : RUN dotnet restore "./webapp.csproj"
 ---> Running in a2ebaf88c8cc
  Restore completed in 3.99 sec for C:\src\webapp.csproj.
Removing intermediate container a2ebaf88c8cc
 ---> 64aab0771dd0
Step 6/10 : COPY . .
 ---> 6186f4120833
Step 7/10 : RUN dotnet build "webapp.csproj" -c Release -o /app/build
 ---> Running in 8b4efb0fab63
Microsoft (R) Build Engine version 16.2.32702+c4012a063 for .NET Core
Copyright (C) Microsoft Corporation. All rights reserved.

  Restore completed in 472.1 ms for C:\src\webapp.csproj.
  webapp -> C:\app\build\webapp.dll
  webapp -> C:\app\build\webapp.Views.dll

Build succeeded.
    0 Warning(s)
    0 Error(s)

Time Elapsed 00:00:08.32
Removing intermediate container 8b4efb0fab63
 ---> 0e256d1346fe
Step 8/10 : RUN dotnet publish "webapp.csproj" -c Release -o /app/publish
 ---> Running in 25589ae6f1b2
Microsoft (R) Build Engine version 16.2.32702+c4012a063 for .NET Core
Copyright (C) Microsoft Corporation. All rights reserved.

  Restore completed in 464.05 ms for C:\src\webapp.csproj.
  webapp -> C:\src\bin\Release\netcoreapp2.2\webapp.dll
  webapp -> C:\src\bin\Release\netcoreapp2.2\webapp.Views.dll
  webapp -> C:\app\publish\
Removing intermediate container 25589ae6f1b2
 ---> e20c0768643a
Step 9/10 : WORKDIR /app/publish
 ---> Running in 8d50795a7e28
Removing intermediate container 8d50795a7e28
 ---> a1d69a022690
Step 10/10 : ENTRYPOINT ["dotnet", "webapp.dll"]
 ---> Running in 68d02f41846f
Removing intermediate container 68d02f41846f
 ---> 52338cd1515f
Successfully built 52338cd1515f
Successfully tagged mywebapp:latest
PS c:\sources\presentation-src-cosmo-docker\webapp> docker run -p 80:80 --name webapp mywebapp
Hosting environment: Production
Content root path: C:\app\publish
Now listening on: http://[::]:80
Application started. Press Ctrl+C to shut down.
```
</details>
&nbsp;<br />
Go to [http://localhost](http://localhost) to see the start page of your application. 
Make sure you remove the container in the end with `docker rm -f webapp`
&nbsp;<br />

### Use a multi-stage image
To further improve the image size, we use a multi-stage image to create the same web app. Microsoft uses a more complicated approach, but we will just use 1 stage for build and publish and then 1 final stage with the results. Again, check the [Dockerfile](https://github.com/tfenster/presentation-src/blob/cosmo-docker/webapp/Dockerfile.multistage) to see the details and then build and run using the following commands.
```bash
docker build -t multistagewebapp -f Dockerfile.multistage .
docker run -p 80:80 --name webapp multistagewebapp
```

<details><summary markdown="span">Full output of multi-stage build and run</summary>
```bash
PS c:\sources\presentation-src-cosmo-docker\webapp> docker build -t multistagewebapp -f Dockerfile.multistage .
Sending build context to Docker daemon  65.54kB
Step 1/12 : FROM mcr.microsoft.com/dotnet/core/sdk:2.2-nanoserver-1809 AS build
 ---> 3e706675d42e
Step 2/12 : WORKDIR /src
 ---> Running in 6f88e6d67dd4
Removing intermediate container 6f88e6d67dd4
 ---> 7f5661844769
Step 3/12 : COPY ["webapp.csproj", "./"]
 ---> f9b01af85809
Step 4/12 : RUN dotnet restore "./webapp.csproj"
 ---> Running in a2e758e92364
  Restore completed in 3.82 sec for C:\src\webapp.csproj.
Removing intermediate container a2e758e92364
 ---> 699ad04c4f5c
Step 5/12 : COPY . .
 ---> d1413e3b9743
Step 6/12 : RUN dotnet build "webapp.csproj" -c Release -o /app/build
 ---> Running in 92a7201bc1c1
Microsoft (R) Build Engine version 16.2.32702+c4012a063 for .NET Core
Copyright (C) Microsoft Corporation. All rights reserved.

  Restore completed in 447.45 ms for C:\src\webapp.csproj.
  webapp -> C:\app\build\webapp.dll
  webapp -> C:\app\build\webapp.Views.dll

Build succeeded.
    0 Warning(s)
    0 Error(s)

Time Elapsed 00:00:08.07
Removing intermediate container 92a7201bc1c1
 ---> 52ea39f093da
Step 7/12 : RUN dotnet publish "webapp.csproj" -c Release -o /app/publish
 ---> Running in f9f293b26c69
Microsoft (R) Build Engine version 16.2.32702+c4012a063 for .NET Core
Copyright (C) Microsoft Corporation. All rights reserved.

  Restore completed in 430.09 ms for C:\src\webapp.csproj.
  webapp -> C:\src\bin\Release\netcoreapp2.2\webapp.dll
  webapp -> C:\src\bin\Release\netcoreapp2.2\webapp.Views.dll
  webapp -> C:\app\publish\
Removing intermediate container f9f293b26c69
 ---> 2298647c1918
Step 8/12 : FROM mcr.microsoft.com/dotnet/core/aspnet:2.2-nanoserver-1809 AS final
 ---> f90066058f41
Step 9/12 : WORKDIR /app
 ---> Running in e7a72bf6dc2d
Removing intermediate container e7a72bf6dc2d
 ---> facfa187ce89
Step 10/12 : EXPOSE 5000
 ---> Running in 48e5940ca332
Removing intermediate container 48e5940ca332
 ---> 9ba0a09335f9
Step 11/12 : COPY --from=build /app/publish .
 ---> 289d28b610db
Step 12/12 : ENTRYPOINT ["dotnet", "webapp.dll"]
 ---> Running in 8473e68a161b
Removing intermediate container 8473e68a161b
 ---> b5132ec417a5
Successfully built b5132ec417a5
Successfully tagged multistagewebapp:latest
PS c:\sources\presentation-src-cosmo-docker\webapp> docker run -p 80:80 --name webapp multistagewebapp
Hosting environment: Production
Content root path: C:\app
Now listening on: http://[::]:80
Application started. Press Ctrl+C to shut down.
```
</details>
&nbsp;<br />
To see the improvements, call `docker images` and compare the sizes for our webapp image and the multistagewebapp image. You should see that the multi-stage image is only 24% of the full image!
```bash
docker images
```

<details><summary markdown="span">Full output of images</summary>
```bash
PS c:\sources\presentation-src-cosmo-docker\webapp> docker images
REPOSITORY                                  TAG                          IMAGE ID            CREATED             SIZE
multistagewebapp                            latest                       b5132ec417a5        4 minutes ago       402MB
mywebapp                                    latest                       52338cd1515f        18 minutes ago      1.68GB
myapache                                    latest                       6e9ba57f7698        2 hours ago         4.89GB
...
```
</details>
&nbsp;<br />
Again, remove the container in the end with `docker rm -f webapp`
&nbsp;<br />
{::options parse_block_html="true" /}
