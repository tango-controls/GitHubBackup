#!/bin/bash 
# A simple script to backup an organization's GitHub repositories.
# Script adapted from https://gist.github.com/darktim/5582423 (which was forked from 
# https://gist.github.com/rodw/3073987) to support proxy and to retrieve more than 30 issues

GHBU_BACKUP_DIR=${GHBU_BACKUP_DIR-"<Your generated backup directory>"}   # where to place the backup files
GHBU_ORG=${GHBU_ORG-"tango-controls"}                                # the GitHub organization whose repos will be backed up
#GHBU_UNAME=${GHBU_UNAME-""}                                         # the username of a GitHub account (to use with the GitHub API)
#GHBU_PASSWD=${GHBU_PASSWD-""}                                       # the password for that account 
GHBU_GITHOST=${GHBU_GITHOST-"github.com"}                            # the GitHub hostname (see notes)
GHBU_TOKEN=${GHBU_TOKEN-"<Your token here>"}                         # Github API token
GHBU_PRUNE_OLD=${GHBU_PRUNE_OLD-true}                                # when `true`, old backups will be deleted
GHBU_PRUNE_AFTER_N_DAYS=${GHBU_PRUNE_AFTER_N_DAYS-3}                 # the min age (in days) of backup files to delete
GHBU_SILENT=${GHBU_SILENT-false}                                     # when `true`, only show error messages 
GHBU_API=${GHBU_API-"https://api.github.com"}                        # base URI for the GitHub API
#GHBU_GIT_CLONE_CMD="git clone --quiet --mirror git@${GHBU_GITHOST}:" # base command to use to clone GitHub repos
GHBU_GIT_CLONE_CMD="git clone --quiet --mirror https://${GHBU_TOKEN}:x-oauth-basic@${GHBU_GITHOST}/" # base command to use to clone GitHub repos via HTTPS using token
#GHBU_GIT_CLONE_CMD="git clone --mirror git@${GHBU_GITHOST}:"         # base command to use to clone GitHub repos - useful to debug
GHBU_PROXY_SETTINGS=${GHBU_PROXY_SETTINGS-""}                        # Proxy settings for curl command - Eg: -x proxy.mydomain.com:7845

TSTAMP=`date "+%Y%m%d-%H%M"`
ORIG_PWD=`pwd`

# The function `check` will exit the script if the given command fails.
function check {
  "$@"
  status=$?
  if [ $status -ne 0 ]; then
    echo "ERROR: Encountered error (${status}) while running the following:" >&2
    echo "           $@"  >&2
    echo "       (at line ${BASH_LINENO[0]} of file $0.)"  >&2
    echo "       Aborting." >&2
	cd ${ORIG_PWD}
    exit $status
  fi
}

# The function `tgz` will create a gzipped tar archive of the specified file ($1) and then remove the original
# the option -P omits the error message tar: Removing leading '/' from member names
function tgz {
   check tar zcPf $1.tar.gz $1 && check rm -rf $1
}

$GHBU_SILENT || (echo "" && echo "=== INITIALIZING ===" && echo "")

$GHBU_SILENT || echo "Using backup directory $GHBU_BACKUP_DIR"
check mkdir -p $GHBU_BACKUP_DIR

check cd ${GHBU_BACKUP_DIR}

$GHBU_SILENT || echo "Fetching list of repositories for ${GHBU_ORG}..."
# cycling through pages as github API limits entries to 30/100 per page...
PAGE=0
while true; do
  let PAGE++
  $GHBU_SILENT || echo "getting page ${PAGE}"
  #REPOLIST_TMP=`check curl ${GHBU_PROXY_SETTINGS} --silent -u $GHBU_UNAME:$GHBU_PASSWD ${GHBU_API}/orgs/${GHBU_ORG}/repos\?page=${PAGE}\&per_page=90 -q -k | grep "\"name\"" | awk -F': "' '{print $2}' | sed -e 's/",//g'`
  REPOLIST_TMP=`check curl ${GHBU_PROXY_SETTINGS} --silent -H "Authorization: token ${GHBU_TOKEN}" ${GHBU_API}/orgs/${GHBU_ORG}/repos\?page=${PAGE}\&per_page=90 -q -k | jq '.[] | { name: .name}' | grep "\"name\"" | awk -F': "' '{print $2}' | sed -e 's/"$//g'`
  if [ -z "${REPOLIST_TMP}" ]; then break; fi
  REPOLIST="${REPOLIST} ${REPOLIST_TMP}"
done


$GHBU_SILENT || echo "found `echo $REPOLIST | wc -w` repositories."


$GHBU_SILENT || (echo "" && echo "=== BACKING UP ===" && echo "")

for REPO in $REPOLIST; do
  $GHBU_SILENT || echo "Backing up ${GHBU_ORG}/${REPO}"
  check ${GHBU_GIT_CLONE_CMD}${GHBU_ORG}/${REPO}.git ${GHBU_BACKUP_DIR}/${GHBU_ORG}-${REPO}-${TSTAMP}.git && tgz ${GHBU_ORG}-${REPO}-${TSTAMP}.git

  $GHBU_SILENT || echo "Backing up ${GHBU_ORG}/${REPO}.wiki (if any)"
  ${GHBU_GIT_CLONE_CMD}${GHBU_ORG}/${REPO}.wiki.git ${GHBU_BACKUP_DIR}/${GHBU_ORG}-${REPO}.wiki-${TSTAMP}.git 2>/dev/null && tgz ${GHBU_ORG}-${REPO}.wiki-${TSTAMP}.git

  $GHBU_SILENT || echo "Backing up ${GHBU_ORG}/${REPO} issues"
  PAGE=0
  while true; do
    let PAGE++
    $GHBU_SILENT || echo "getting page ${PAGE}"
	# ISSUES_TMP=`check curl ${GHBU_PROXY_SETTINGS} --silent -u $GHBU_UNAME:$GHBU_PASSWD ${GHBU_API}/repos/${GHBU_ORG}/${REPO}/issues\?page=${PAGE}\&per_page=50\&state=all -q` # && tgz ${GHBU_BACKUP_DIR}/${GHBU_ORG}-${REPO}.issues-${TSTAMP}`
    ISSUES_TMP=`check curl ${GHBU_PROXY_SETTINGS} --silent -H "Authorization: token ${GHBU_TOKEN}" ${GHBU_API}/repos/${GHBU_ORG}/${REPO}/issues\?page=${PAGE}\&per_page=50\&state=all -q`
	check echo "$ISSUES_TMP" >> ${GHBU_BACKUP_DIR}/${GHBU_ORG}-${REPO}.issues-${TSTAMP}
	NUM_ISSUES=`echo "$ISSUES_TMP" | grep -c "^    \"number\":"`
	$GHBU_SILENT || echo "number of issues on page ${PAGE}: ${NUM_ISSUES}"
    if [ "${NUM_ISSUES}" -lt 50 ]; then break; fi
  done
  check tgz ${GHBU_ORG}-${REPO}.issues-${TSTAMP}
done

if $GHBU_PRUNE_OLD; then
  $GHBU_SILENT || (echo "" && echo "=== PRUNING ===" && echo "")
  $GHBU_SILENT || echo "Pruning backup files ${GHBU_PRUNE_AFTER_N_DAYS} days old or older."
  $GHBU_SILENT || echo "Found `find $GHBU_BACKUP_DIR -name '*.tar.gz' -mtime +$GHBU_PRUNE_AFTER_N_DAYS | wc -l` files to prune."
  find $GHBU_BACKUP_DIR -name '*.tar.gz' -mtime +$GHBU_PRUNE_AFTER_N_DAYS -exec rm -fv {} > /dev/null \; 
fi
# come back to original directory
cd ${ORIG_PWD}

$GHBU_SILENT || (echo "" && echo "=== DONE ===" && echo "")
$GHBU_SILENT || (echo "GitHub backup completed." && echo "")

