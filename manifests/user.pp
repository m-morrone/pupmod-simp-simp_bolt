# NOTE: THIS IS A [PRIVATE](https://github.com/puppetlabs/puppetlabs-stdlib#assert_private) CLASS**
#
# Configure a 'simp_bolt' system user
#
# @param username
#   The username to use for remote access
#
# @param password
#   The password for the user in passwd-compatible salted hash form
#
# @param home
#   The full path to the user's home directory
#
# @param uid
#   The UID of the user
#
# @param gid
#   The GID of the user
#
# @param ssh_authorized_key
#   The SSH public key for the user
#
#   * See the native ``ssh_authorized_key`` resource definition for details
#
# @param ssh_authorized_key_type
#   The SSH public key type
#
#   * See the native ``ssh_authorized_key`` resource definition for details
#
# @param sudo_users
#   The users that the ``username`` user may escalate to
#
# @param sudo_password
#   Require password for user to sudo
#
# @param sudo_commands
#   The commands that the ``username`` user is allowed to execute via sudo as one
#   of the allowed users
#
# @param allowed_from
#   The ``pam_access`` compatible locations that the user will be logging in
#   from
#
#   * Set to ``['ALL']`` to allow from any location
#
# @param max_logins
#   The ``pam_limits`` restricting the number of concurrent sessions permitted for
#   ``username``
class simp_bolt::user (
  Boolean             $enable                  = true,
  String              $username                = 'simp_bolt',
  Optional[String[8]] $password                = undef,
  Pattern['^/']       $home                    = "/var/local/${username}",
  Integer             $uid                     = 1779,
  Integer             $gid                     = $uid,
  Optional[String[1]] $ssh_authorized_key      = undef,
  String[1]           $ssh_authorized_key_type = 'ssh-rsa',
  String              $sudo_users              = 'root',
  Boolean             $sudo_password           = true,
  Array[String]       $sudo_commands           = ['ALL'],
  Array[String]       $allowed_from            = [ $::servername ],
  Integer             $max_logins              = 1
) {
  assert_private()

  $_ensure = $enable ? {
    true    => 'present',
    default => 'absent'
  }

  if $enable{
    unless ($password or $ssh_authorized_key) {
      fail("You must specify either 'simp_bolt::user::password' or 'simp_bolt::user::ssh_authorized_key'")
    }
  }

  if $enable {
    file { $home:
      owner   => $username,
      group   => $username,
      mode    => '0640',
      seltype => 'user_home_dir_t'
    }

# Restrict login to ssh from Bolt servers unless system is Bolt server, in which case also permit 
# local login
    if $::simp_bolt::bolt_server {
      $_allowed_from = ['LOCAL'] + $allowed_from
    } else {
      $_allowed_from = $allowed_from
    }
    pam::access::rule { "allow_${username}":
      users   => [$username],
      origins => $_allowed_from,
      comment => 'SIMP BOLT user, restricted to remote access from specified BOLT systems'
    }

# Include an extra login session on the server to allow for running Bolt on itself
    if $::simp_bolt::bolt_server {
      $_max_logins = $max_logins + 1
    } else {
      $_max_logins = $max_logins
    }
    pam::limits::rule { "limit_${username}":
      domains => [$username],
      type    => 'hard',
      item    => 'maxlogins',
      value   => $_max_logins
    }

    sudo::user_specification { $username:
      user_list => [$username],
      runas     => $sudo_users,
      cmnd      => $sudo_commands,
      passwd    => $sudo_password
    }
  }

  group { $username:
    ensure => $_ensure,
    gid    => $gid
  }

  user { $username:
    ensure     => $_ensure,
    password   => $password,
    comment    => 'SIMP Bolt User',
    uid        => $uid,
    gid        => $gid,
    home       => $home,
    managehome => true
  }

  ssh_authorized_key { $username:
    ensure => $_ensure,
    key    => $ssh_authorized_key,
    type   => $ssh_authorized_key_type,
    user   => $username
  }

}
