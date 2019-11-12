#!/bin/sh

yum --showduplicates list puppet-agent-${PT_version} >/dev/null 2>&1
if [ $? = 0 ]; then
  # Check for specified version and return if available
  echo "$PT_version"
else
  # Determine most recent puppet-agent version
  version=`yum --showduplicates list puppet-agent|grep puppet-agent|awk {'print $2'}|sort --version-sort|tail -1`
  if [ -z $version ]; then
    # Return 0 if puppet-agent is not found in available repos
    echo "0"
  else
    # Return most recent version of puppet-agent found in repos
    echo "${version}"
  fi
fi

