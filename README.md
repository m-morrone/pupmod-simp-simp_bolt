**FIXME**: Ensure the badges are correct and complete, then remove this message!

[![License](https://img.shields.io/:license-apache-blue.svg)](http://www.apache.org/licenses/LICENSE-2.0.html)
[![CII Best Practices](https://bestpractices.coreinfrastructure.org/projects/73/badge)](https://bestpractices.coreinfrastructure.org/projects/73)
[![Puppet Forge](https://img.shields.io/puppetforge/v/simp/simp_bolt.svg)](https://forge.puppetlabs.com/simp/simp_bolt)
[![Puppet Forge Downloads](https://img.shields.io/puppetforge/dt/simp/simp_bolt.svg)](https://forge.puppetlabs.com/simp/simp_bolt)
[![Build Status](https://travis-ci.org/simp/pupmod-simp-simp_bolt.svg)](https://travis-ci.org/simp/pupmod-simp-simp_bolt)

#### Table of Contents

1. [Description](#description)
2. [Setup - The basics of getting started with simp_bolt](#setup)
    * [What simp_bolt affects](#what-simp_bolt-affects)
    * [Beginning with simp_bolt](#beginning-with-simp_bolt)
3. [Usage - Configuration options and additional functionality](#usage)
4. [Reference - An under-the-hood peek at what the module is doing and how](#reference)
5. [Limitations - OS compatibility, etc.](#limitations)
6. [Development - Guide for contributing to the module](#development)
    * [Acceptance Tests - Beaker env variables](#acceptance-tests)

---

    +----------------------------------------------------------------+
    | WARNING: This is currently an **EXPERIMENTAL** module. Things  |
    | may change drastically, and in breaking ways, without notice!  |
    +----------------------------------------------------------------+

---

## Description

This module manages Puppet Bolt. It installs and configures the necessary 
packages on systems specified as Bolt controllers and configures accounts as
specified on both controllers and target systems to be managed with Bolt.

Bolt is an open source task runner developed by Puppet that permits automation
on an as-needed basis. This means that all actions are initiated from the Bolt
server, eliminating reliance upon remote agent software for task execution.
More complex tasks can be implemented using Puppet modules, which does require
the installation of an agent for executions, but all tasks are still initiated
from the Bolt server.

### This is a SIMP module

This module is a component of the 
[System Integrity Management Platform](https://simp-project.com), a
compliance-management framework built on Puppet.

If you find any issues, they may be submitted to our 
[bug tracker](https://simp-project.atlassian.net/).

This module is optimally designed for use within a larger SIMP ecosystem, but
it can be used independently:

 * When included within the SIMP ecosystem, security compliance settings will
   be managed from the Puppet server.
 * If used independently, all SIMP-managed security subsystems are disabled by
   default and must be explicitly opted into by administrators.  Please review
   the parameters in
   [`simp/simp_options`](https://github.com/simp/pupmod-simp-simp_options) for
   details.

## Setup

### What simp_bolt affects

The simp_bolt module can create a local user account on target systems,
simp_bolt by default, that has the ability to `su` to the root user on the
system. Every effort has been taken to implement this as securely as possible by
including an option to manage user security settings. Due to the potential to
effectively lockout the account, the root user is not permitted to be specified
as the target user account. The target user can be restricted to only login via
ssh from specified hosts and also limited to only one login session at a time 
for the execution of tasks. Multiple ssh keys can be specified for the target
user to permit different user accounts on the controller to run bolt and provide
a degree of attestation.


The target user's home directory defaults to /var/local/simp_bolt. This location
is used for temporary files on the target systems. This can be configured to a
different location if desired.

Bolt logs are written to the /var/log/puppetlabs/bolt by default, and the 
directory structure will be created if necessary. This can also be configured
to an alternate location.

By default, Bolt collects various analytics associated with a random UUID, 
non-identifiable user, details are available at 
[Analytics data collection](https://puppet.com/docs/bolt/latest/bolt_installing.html#concept-8242)
. The simp_bolt module overrides and disables this by default, but it can 
be re-enabled in Hiera.

The simp_bolt module leverages the `simp/pam` and `simp/sudo` modules 
for implementation and will install them if necessary.

### Beginning with simp_bolt

To configure a system as a Bolt controller, include the SIMP Bolt class and specify
the system as a `bolt_controller` in Hiera.

```yaml
classes:
  - simp_bolt
simp_bolt::bolt_controller: true
```

To configure a system that will be managed by Bolt, simply include the SIMP Bolt
class and specify the system as a ``bolt_target`` in Hiera.

```yaml
classes:
  - simp_bolt
simp_bolt::bolt_target: true
```

Additionally, either a password or ssh key must be specified for configuration
of ssh to remote systems. Both can be specified in Hiera.  Passwords should be
in **passwd-compatible salted hash** form.

```yaml
simp_bolt::user::password: '$6$0BVLUF[...]16OtkdiY1'
simp_bolt::user::ssh_authorized_key: 'AAAAB3Nza[...]qXfdaQ=='
```

## Usage

Once the simp_bolt module has been applied to a server and one or more target
systems, Bolt is ready for use. All commands provided assume you have changed
users to the appropriate account using `su` on the Bolt server system.
Entering the command `bolt` by itself will display the help information.

To run a remote command, `su` to the bolt user and execute
`bolt command run <COMMAND> --nodes <NODE NAME(S)> --password --sudo-password`.
By omitting values for password and sudo-password from the command line, the
user will be prompted to enter the password so it will not be displayed on the
command line. Commands can be run on multiple nodes by specifying additional 
<NODE NAME> values, using commas to separate entries.

To view available modules, `su` to the bolt user and execute
`bolt puppetfile show-modules`.
Additional modules already on the system can be added by specifying the full
path to their parent directory in Hiera:

```yaml
simp_bolt::config::modulepath: /path/to/modules
```

To apply an existing manifest, `su` to the bolt user and execute
`bolt apply <manifest> --nodes <NODE NAME(S)> --password --sudo-password`.

## Reference

Please for refer to the online [Bolt](https://puppet.com/docs/bolt/latest/bolt.html)
documentation for the most up to date documenation.

## Limitations

SIMP Puppet modules are generally intended for use on Red Hat Enterprise Linux
and compatible distributions, such as CentOS. Please see the
[`metadata.json` file](./metadata.json) for the most up-to-date list of
supported operating systems, Puppet versions, and module dependencies.

## Development

Please read our [Contribution Guide](https://simp.readthedocs.io/en/stable/contributors_guide/index.html).

### Acceptance tests

This module includes [Beaker](https://github.com/puppetlabs/beaker) acceptance
tests using the SIMP [Beaker Helpers](https://github.com/simp/rubygem-simp-beaker-helpers).
By default the tests use [Vagrant](https://www.vagrantup.com/) with
[VirtualBox](https://www.virtualbox.org) as a back-end; Vagrant and VirtualBox
must both be installed to run these tests without modification. To execute the
tests run the following:

```shell
bundle install
bundle exec rake beaker:suites
```

Please refer to the [SIMP Beaker Helpers documentation](https://github.com/simp/rubygem-simp-beaker-helpers/blob/master/README.md) for more information.
