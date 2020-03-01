---
layout: page
title: "7 Docker Compose"
description: ""
keywords: ""
permalink: "cosmo-docker-7-docker-compose"
slug: "cosmo-docker-7-docker-compose"
---
{::options parse_block_html="true" /}
Table of content
- [WordPress with a MySQL backend and admin tool](#wordpress-with-a-mysql-backend-and-admin-tool)

&nbsp;<br />

### WordPress with a MySQL backend and admin tool
As an example we will create a WordPress installation where one container holds WordPress itself and one container holds the MySQL database. Additionally we will add a SQL web interface so that we can check if the WordPress database inside of our MySQL container is created. You can find the docker-compose.yml [here](https://github.com/tfenster/presentation-src/blob/cosmo-docker/wordpress/docker-compose.yml) and after downloading docker compose, we just call the `up` command to start all three containers.
```bash
Invoke-WebRequest "https://github.com/docker/compose/releases/download/1.24.1/docker-compose-Windows-x86_64.exe" -UseBasicParsing -OutFile $Env:ProgramFiles\Docker\docker-compose.exe
cd c:\sources\presentation-src-cosmo-docker\wordpress
docker-compose up
```

<details><summary markdown="span">Full output of docker-compose up</summary>
```bash
PS C:\Users\CosmoAdmin\Desktop> Invoke-WebRequest "https://github.com/docker/compose/releases/download/1.24.1/docker-compose-Windows-x86_64.exe" -UseBasicParsing -OutFile $Env:ProgramFiles\Docker\docker-compose.exe
PS C:\Users\CosmoAdmin\Desktop> cd c:\sources\presentation-src-cosmo-docker\wordpress
PS c:\sources\presentation-src-cosmo-docker\wordpress> docker-compose up
Creating network "wordpress_default" with the default driver
Creating wordpress_db_1      ... done
Creating wordpress_adminer_1 ... done
Creating wordpress_wp_1      ... done
Attaching to wordpress_db_1, wordpress_adminer_1, wordpress_wp_1
db_1       | VERBOSE: Setting PATH for MySQL Server
db_1       |
db_1       | SUCCESS: Specified value was saved.
db_1       | VERBOSE: Starting MySQL Server
db_1       | VERBOSE: Creating database wordpress
db_1       | VERBOSE: Changing MySQL root password
```
</details>
&nbsp;<br />
Now go to [http://localhost:8080](http://localhost:8080) in your browser to start the WordPress installation. After selecting the language, give it a title, an admin username and either overwrite the password or copy the predefined value. Also enter your email address. If you the click on "Install WordPress", it will set up the database in the second container and after a couple of seconds, WordPress is up and running.<br />
After that, go to [http://localhost:8000](http://localhost:8000) to access the "adminer" SQL web interface. Use "db" as server name because our MySQL service in the docker compose definition was named "db" and use root / rootpassword as access information, again because we defined it that way in the docker compose definition. After login you should see that a "wordpress" database was generated. Feel free to generate posts in WordPress, it should be fully operational.<br />&nbsp;<br />
To see the running containers, open a second PowerShell and call `docker ps`.
<details><summary markdown="span">Full output of docker ps</summary>
```bash
PS C:\Users\CosmoAdmin> docker ps
CONTAINER ID        IMAGE                                         COMMAND                  CREATED             STATUS              PORTS                               NAMES
4461b8151c57        dshatohin/wordpress-servercore:5.2-1809       "powershell -Command…"   10 minutes ago      Up 10 minutes       0.0.0.0:8080->80/tcp                wordpress_wp_1
bb8f69610ca3        dshatohin/adminer-servercore:4.7-nginx-1809   "powershell -Command…"   10 minutes ago      Up 10 minutes       0.0.0.0:8000->80/tcp                wordpress_adminer_1
ea1f1d37166b        dshatohin/mysql-servercore:5.7-1809           "powershell -Command…"   10 minutes ago      Up 10 minutes       0.0.0.0:3306->3306/tcp, 33060/tcp   wordpress_db_1
```
</details>
&nbsp;<br />
To remove everything again, hit Ctrl-C in your first PowerShell session to stop the containers and then call `docker-compose down` afterwards to remove them.
<details><summary markdown="span">Full output of docker-compose down</summary>
```bash
Gracefully stopping... (press Ctrl+C again to force)
Stopping wordpress_wp_1      ... done
Stopping wordpress_adminer_1 ... done
Stopping wordpress_db_1      ... done
PS c:\sources\presentation-src-cosmo-docker\wordpress> docker-compose down
Removing wordpress_wp_1      ... done
Removing wordpress_adminer_1 ... done
Removing wordpress_db_1      ... done
Removing network wordpress_default
```
</details>
&nbsp;<br />
{::options parse_block_html="true" /}
