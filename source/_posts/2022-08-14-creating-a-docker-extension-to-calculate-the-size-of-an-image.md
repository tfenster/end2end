---
layout: post
title: "Creating a Docker extension to calculate the size of an image"
permalink: creating-a-docker-extension-to-calculate-the-size-of-an-image
date: 2022-08-14 21:27:21
comments: false
description: "Creating a Docker extension to calculate the size of an image"
keywords: ""
image: /images/docker-image-size3.png
categories:

tags:

---

Ever since the [announcement][announcement] of [Docker extensions][docker-extensions] three months ago, I was intrigued, and I immediately installed the nice "Disk usage" extension. However, being a developer, I wanted to also try creating my own extension, but I've done too many "hello worlds" in my life, so I had to wait for a somewhat interesting idea. Fortunately, my fellow Microsoft MVP, [Albert Tanure][atanure], asked a question that sparked a thought: Wouldn't if be nice to have an easy way to find out the size of an image, without having to pull it? A couple of hours later, my "Image size" Docker extension was born!

## The TL;DR
If you just want to use it, you can run `docker extension install tobiasfenster/image-size-extension:latest`. This will pull the image from the Docker hub and install the extension in Docker Desktop. You will get a very easy interface, where you just put in the image name and optionally tag as you would when pulling the image. E.g. you could enter `hello-world` as image name and click the "Get image size" button. After a couple of seconds, you should see the following:

![screenshot of docker desktop with images size extension](/images/docker-image-size1.png)
{: .centered}

As you maybe know or can easily guess from looking at the screenshot, the `hello-world` image supports different architectures and OSes. If you expand one of them, you see the size of the config, the total size of all layers and the total size of the image, which is the sum of the config and all layers. You can also expand the layers to see the size of each individual layer.

![screenshot of docker desktop with images size extension and one image and its layers expanded](/images/docker-image-size2.png)
{: .centered}

Note that this is the compressed size of the image.

## The details: Creating the extension

Creating the extension was very easy. First, I followed the great [quickstart][quickstart] doc to get started and ran `docker extension init image-size-extension`. It asks for the repository, a description, vendor and extension SDK version (where I left the default):

{% highlight powershell linenos %}
docker extension init image-size-extension

? Hub Repository: tobiasfenster/image-size-extension
? Description: A Docker extension for getting the size of an image without pulling
? Vendor: Tobias Fenster
? Extension SDK version: >= 0.2.3
{% endhighlight %}

With `docker build -t tobiasfenster/image-size-extension .` and `docker extension install tobiasfenster/image-size-extension:latest`, building and installing the extension is as easy as possible.

The `extension init` command gave me a setup with a React-based frontend and a Go-based backend, but I quickly realized that I only needed a frontend as I could do the very small piece of "logic" equally well in my frontend with TypeScript. Next time, I would probably follow the instructions [here][gui-extension], but it worked out well enough. 

As a first step after the users clicks on the "Get image size" button, the equivalent to a `docker manifest inspect <imagename> -v` is done:

{% highlight typescript linenos %}
const manifestInfo = await ddClient.docker.cli.exec("manifest", [
  "inspect",
  imagename,
  "-v"
]);
{% endhighlight %}

As you can see, you can interact with the Docker CLI in a Docker extension through `ddClient.docker.cli`, in this case executing a `docker manifest` call. You can also interact with Docker Desktop, which we will see further down.

As the second step, the results are transformed into a [`Tree view`][tree]. Because I have created [interfaces] for the result of the `docker manifest` call, I can call properties of the result in a typed way. First, the root element is created: 

{% highlight typescript linenos %}
{% raw %}
<TreeView
aria-label="image size view"
defaultCollapseIcon={<ExpandMoreIcon />}
defaultExpandIcon={<ChevronRightIcon />}
sx={{ flexGrow: 1, overflowY: 'auto' }}
disableSelection={true}
>
...
</TreeView>
{% endraw %}
{% endhighlight %}

Then, I get a reference which has the full name of the image, the OS and the OS version (relevant on Windows):

{% highlight typescript linenos %}
{
    manifests.map((manifest: Manifest, index: number) => {
    var localRef = manifest.Ref;
    if (localRef.indexOf("@") > 0)
        localRef = localRef.substring(0, localRef.indexOf("@"));

    localRef += ` (${manifest.Descriptor.platform.os} - ${manifest.Descriptor.platform.architecture}`;
    if (manifest.Descriptor.platform["os.version"] !== undefined)
        localRef += ` - ${manifest.Descriptor.platform["os.version"]}`;
    localRef += ")";
    ...
}
{% endhighlight %}

The next part is to calculate the different size elements, including the sum of all layer sizes:

{% highlight typescript linenos %}
var configSize = manifest.SchemaV2Manifest.config.size;
var totalLayerSize = configSize;
manifest.SchemaV2Manifest.layers.forEach((layer: Layer) => {
    totalLayerSize += layer.size;
});
var totalSize = configSize + totalLayerSize;
{% endhighlight %}

In the end, all of this is put into `TreeItem`s

{% highlight typescript linenos %}
<TreeItem nodeId={`${index}`} key={`${index}`} label={localRef}>
<TreeItem nodeId={`${index}-total`} key={`${index}-total`} label={`Total size: ${formatBytes(totalSize)}`} />
<TreeItem nodeId={`${index}-config`} key={`${index}-config`} label={`Config size: ${formatBytes(configSize)}`} />
<TreeItem nodeId={`${index}-layers`} key={`${index}-layers`} label={`Layers size: ${formatBytes(totalLayerSize)}`} >
    {
    manifest.SchemaV2Manifest.layers.map((layer: Layer, indexLayer: number) => {
        return (
        <TreeItem nodeId={`${index}-${indexLayer}-layer`} key={`${index}-${indexLayer}-layer`} label={`Layer size: ${formatBytes(layer.size)} ${layer.urls !== undefined ? " - external" : ""}`} />
        );
    })
    }
</TreeItem>
</TreeItem>
{% endhighlight %}

If something goes wrong, an error toast is show in Docker Desktop, so this shows you how you interact with the overall GUI from an extension as well:

{% highlight TypeScript linenos %}
try {
    ...
} catch (e) {
    setManifests(undefined);
    ddClient.desktopUI.toast.error(e.stderr);
}
{% endhighlight %}

And that's more or less the full relevant code. You can also take a look at the full sources in the [repo], where probably [App.tsx] is the most interesting file. 

After that, I added the required meta information in [metadata.json] and removed the backend part and changed the icon in the [Dockerfile]. But all of that is quite straight-forward. The only issue I ran into was that updating the extension didn't work for me as expected: When I call `docker extension update tobiasfenster/image-size-extension:latest`, I get something like this:

{% highlight PowerShell linenos %}
Warning: extension image tobiasfenster/image-size-extension:latest could not be removed: executing 'docker --context default image remove tobiasfenster/image-size-extension:latest' : exit status 1:
Error response from daemon: conflict: unable to remove repository reference "tobiasfenster/image-size-extension:latest" (must force) - container d75100f20263 is using its referenced image e6501cb2fa84
{% endhighlight %}

Fortunately the solution is quite easy: You just need to remove the container in your container list in VS Code and afterwards, the `update` command works well. If I ran into an issue as explained above, I always had to restart Docker Desktop. Slightly annoying, but I am pretty sure that this kind of early issues will be resolved soon.

Overall, this is a great and easy way to extend Docker Desktop with your own functionality. This time, it took me a couple of hours, but I am pretty sure that for a problem like this, I would be able to get it done in an hour in the future. With the Docker hub as delivery mechanism, this opens up a lot of opportunities to make your development work faster and easier, all in a very convenient and quickly distributable way.

As a next step, I plan to investigate how publishing to the Docker extension marketplace works. Stay tuned!

[docker-extensions]: https://www.docker.com/products/extensions/
[announcement]: https://www.docker.com/blog/docker-extensions-discover-build-integrate-new-tools-into-docker-desktop/
[atanure]: https://twitter.com/alberttanure
[quickstart]: https://docs.docker.com/desktop/extensions-sdk/quickstart/
[gui-extension]: https://docs.docker.com/desktop/extensions-sdk/build/set-up/react-extension/
[interfaces]: https://github.com/tfenster/image-size-extension/blob/c60e61b69e2667a3a203c3d22613e797cc400983/ui/src/App.tsx#L31-L68
[tree]: https://mui.com/material-ui/react-tree-view/
[repo]: https://github.com/tfenster/image-size-extension
[App.tsx]: https://github.com/tfenster/image-size-extension/blob/main/ui/src/App.tsx
[metadata.json]: https://github.com/tfenster/image-size-extension/blob/main/metadata.json
[Dockerfile]: https://github.com/tfenster/image-size-extension/commit/c60e61b69e2667a3a203c3d22613e797cc400983#diff-dd2c0eb6ea5cfc6c4bd4eac30934e2d5746747af48fef6da689e85b752f39557