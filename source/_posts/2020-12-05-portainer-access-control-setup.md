---
layout: post
title: "Portainer access control setup"
permalink: portainer-access-control-setup
date: 2020-12-05 21:14:06
comments: false
description: "Portainer access control setup"
keywords: ""
categories:
image: /images/portainer.png

tags:

---

[Portainer][portainer] is a great tool to simplify container management, that I've been using for quite some time by now. In fact, my first blog post [on that topic][old-blog] is from July 2017, and we are now relying on it as part of our Azure DevOps & Docker self-service offering. I had a blog post about the setup of access control in Portainer in my blog backlog for a while now, because it took me a long time to figure out how it works through the API as it is way more complicated than necessary and needs ugly workarounds. Or at least I thought that, until I came across this [pull request][pr] because of a discussion on the Portainer slack.

## The TL;DR

You can in fact very easily allow users or teams access. Assuming that we have a team dev, you can add a label like this

```
"io.portainer.accesscontrol.teams=dev"
```

to give that team access. Or if you have two users `alice` and `bob`, you can add a label like this

```
"io.portainer.accesscontrol.users=alice,bob"
```

to give those users access. Pretty nice and easy! Unfortunately this is not documented at the moment, but I heard that documentation will follow soon. We currently have a need to set this up on services, containers and volumes, which works fine. In combination with the OAuth integration which allows us to have SSO with our Azure AD, the whole user and access control story is very convenient.

Actually there is nothing more to say about this, so I'll keep it at that, which probably makes this my shortest blog post ever. Just one more thing to add: Keep your eyes on Portainer next week, I hear big things are coming.


[portainer]: https://portainer.io
[old-blog]: https://www.axians-infoma.de/techblog/nav-on-docker-with-portainer/
[pr]: https://github.com/portainer/portainer/pull/3337