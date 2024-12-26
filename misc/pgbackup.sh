#!/bin/bash

# Error trapping from https://gist.github.com/oldratlee/902ad9a398affca37bfcfab64612e7d1
__error_trapper() {
  local parent_lineno="$1"
  local code="$2"
  local commands="$3"
  echo "error exit status $code, at file $0 on or near line $parent_lineno: $commands"
}
trap '__error_trapper "${LINENO}/${BASH_LINENO}" "$?" "$BASH_COMMAND"' ERR

set -euE -o pipefail
shopt -s failglob

set -x

cd /srv/backups

# Delete old backups; we don't need that many because we have daily
# offsite backups
ls -1rt | head -n -40 | xargs rm -f -v

for database in $(psql -q -t -c 'select datname from pg_database;' | grep -v template0)
do
  DATESTR=$(TZ=America/Los_Angeles date +%Y-%m-%d)

  echo "Backing up PostgreSQL database $database"
  /usr/bin/pg_dump -C -Fc $database -f ./$database.$DATESTR

  echo "Optimizing PostgreSQL database $database"
  psql -t -d $database -c 'vacuum full analyze;'
  psql -t -d $database -c "reindex database $database;"
done

echo "postgres backup complete"
