# discord.sh
Discord Bot using POSIX Shell

The simplest way to create a Discord bot on a unix system. Meant to be a
tool helping people to learn about shell scripting and automating stuff like 
talking to APIs. The only requirements are:

+ a POSIX compliant shell (e.g. bash, ksh, dash, ...)
+ `curl`
+ [`jq`](https://github.com/stedolan/jq) (json parsing utility)
+ coreutils (namely `tr`, `seq`, `sleep`, `date`)

Create a bot on [Discord](discord.com) (make sure to enable the messages
content intent), invite it to your server with the rights to read and send
messages and edit the `config.sh` file.

## Roadmap
+ more commands
+ Would be probably not a bad idea to get rid of `jq`, as this makes the whole script way less portible.
