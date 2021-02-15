# GitHubBackup
A simple script to backup an organization's GitHub repositories with their issues and wikis.

This script is adapted from https://gist.github.com/darktim/5582423 (which was forked from https://gist.github.com/rodw/3073987) to support proxy and to retrieve more than 30 issues and authentication via TOKEN.

The following environment variables can be defined to make this script fit to your needs:
* GHBU_BACKUP_DIR: the directory where the backup files will be generated
* GHBU_ORG: name of the GitHub organization whose repositories with issues and wikis will be backed up (default = tango-controls)
* GHBU_GITHOST: GitHub hostname (default = github.com)
* GHBU_TOKEN: GitHub API token (See https://help.github.com/articles/creating-an-access-token-for-command-line-use/ for more details)
* GHBU_PRUNE_OLD: when true, backups older than GHBU_PRUNE_AFTER_N_DAYS will be deleted (default = true)
* GHBU_PRUNE_AFTER_N_DAYS: the minimum age in days of backup files to delete (default = 3 (days))
* GHBU_SILENT: when true, only shows error messages (default = false)
* GHBU_API: base URI for the GitHub API (default = https://api.github.com)
* GHBU_GIT_CLONE_CMD: base command to use to clone GitHub repositories (default = "git clone --quiet --mirror git@${GHBU_GIHOST}:")
* GHBU_PROXY_SETTINGS: Proxy settings for curl command. For instance "-x proxy.mydomain.com:1234". (Default = "")

Script requires jq; install with `apt install jq` on Ubuntu.

The script will generate per repository X from the target organization:
* a tar.gz file containing the git repository X
* a tar.gz containing the git repository of this X repository's wiki 
* a tar.gz containing a json file with all the issues of repository X

The git repositories are cloned with --mirror option so the result will be quite different from what we get after a classical git clone.<BR>
To get a working copy, in your current directory, of a repository which was saved by this backup script, one should extract the tar.gz containing the git repository backup and then execute the following command: <BR> `git clone /path/to/your/extracted/git/your_repository.git .`

You can use a cron job to run this script. One way to use this script is to create a .github_backuprc file in the home directory of the user which will run the cron, with rwx------ permissions (rwx only for the user since the GitHub API token will be saved into this file).
This file will look like the following:
```
export GHBU_TOKEN=your_token_here
export GHBU_BACKUP_DIR=/where/you/want/your/backups
export GHBU_PROXY_SETTINGS="-x myproxy.mydomain.com:1234"
export GHBU_PRUNE_AFTER_N_DAYS=5
```

Here is an example of a crontab you can use to execute the backup script every day at 09:00 am and send an e-mail once the script has completed its work:
```
#
# Backup tango-controls GitHub organization
#
00 09 * * * . /home/my_username/.github_backuprc; /path/to/backup/script/backup-github.sh | mailx -s "[cron-github-backup] tango-controls" my_email_address@mydomain.com >/dev/null 2>&1
```
