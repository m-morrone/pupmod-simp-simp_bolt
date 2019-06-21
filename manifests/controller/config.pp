# **NOTE: THIS IS A [PRIVATE](https://github.com/puppetlabs/puppetlabs-stdlib#assert_private) CLASS**
#
# @summary Set the global configuration and transport options for Bolt.
#
# Addtional details on the options can be found at
# https://puppet.com/docs/bolt/latest/bolt_configuration_options.html.
#
# @param local_group
#   The local group to be used for file permissions associated with the local_user account. The
#   default is the $username account specified in the user.pp manifest.
#
# @param local_user_home
#   The home directory of the local account to be used for running Bolt. The default is the
#   $home directory for the account specified in the user.pp manifest.
#
# @param local_user
#   The local account to be used for running Bolt. The default is the $username account specified
#   in the user.pp manifest.
#
# @param config_hash
#   If specified, will be passed to the ``to_yaml`` function and output at the
#   entire configuation of the ``bolt.yaml`` configuation file.
#
#   * No further options will be honored if this is specified
#
# @param color
#   Whether to use colored output when printing messages to the console. By default, in Bolt,
#   this is true.
#
# @param concurrency
#   The number of threads to use when executing on remote nodes. By default, in Bolt, this
#   is 100.
#
# @param default_transport
#   The default transport to use when not specified in the URL or inventory.
#
# @param disable_analytics
#   Disable all vendor 'phone-home' mechanics in Bolt.
#
# @param format
#   The format to use when printing results; either human or json. By default, in Bolt, this
#   is human.
#
# @param hiera_config
#   The path to the Hiera config file. By default, in Bolt, this is `hiera.yaml` in the Bolt
#   project directory at `~/.puppetlabs/bolt`.
#
# @param inventoryfile
#   Path to a structured data inventory file used to refer to groups of nodes on the command
#   line and from plans. By default, in Bolt, this is `inventory.yaml` in the Bolt project
#   directory at `~/.puppetlabs/bolt`.
#
# @param log_console_level
#   The type of information to display on the console. Valid options are debug, info, notice,
#   warn, and error. The default is info.
#
# @param log_file
#   The path and name of the log file.
#
# @param log_file_level
#   The type of information to record in the log file. Valid options are debug, info, notice,
#   warn, and error. By default in Bolt this is info.
#
# @param log_file_append
#   Add output to an existing log file. By default in Bolt this is true.
#
# @param modulepath
#   The module path for loading tasks and plan code, formatted as a string containing a list
#   of directories. The first directory listed will be the default for downloaded modules.
#   By default, in Bolt, this is "modules:site-modules:site" within the Bolt project directory
#   in `~/.puppetlabs/bolt`.
#
# @params transport_options
#   A Hash of transport options that will be added to the configuration file
#   without any error checking of key/value pairs.
#
#   You must have settings specified for the ``$default_transport``
#
class simp_bolt::controller::config (
  # Local Target Directory Options
  Optional[String[1]]              $local_user         = getvar(simp_bolt::controller::local_user_name),
  Optional[String[1]]              $local_group        = getvar(simp_bolt::controller::local_group_name),
  Stdlib::Unixpath                 $local_home         = pick(getvar(simp_bolt::controller::local_user_home), '/var/local/simp_bolt'),

  # Config File Specification
  Optional[Hash]                   $config_hash        = undef,

  # Global Bolt Options
  Boolean                          $color              = true,
  Optional[Integer[0]]             $concurrency        = undef,
  Simp_bolt::Transport             $default_transport  = 'ssh',
  Boolean                          $disable_analytics  = true,
  Optional[Enum['human','json']]   $format             = undef,
  Optional[String[1]]              $hiera_config       = undef,
  Optional[String[1]]              $inventoryfile      = undef,
  Simp_bolt::LogLevel              $log_console_level  = 'info',
  Boolean                          $log_file_append    = false,
  Simp_bolt::LogLevel              $log_file_level     = 'info',
  Stdlib::Unixpath                 $log_file           = '/var/log/puppetlabs/bolt/bolt.log',
  Optional[String[1]]              $modulepath         = undef,

  # Overall Transport Options
  Hash[Simp_bolt::Transport, Hash] $transport_options  = {
                                                            'ssh' => {
                                                              'tmpdir' => $simp_bolt::target_user_home,
                                                              'user'   => $simp_bolt::target_user_name,
                                                              'run-as' => getvar(simp_bolt::target_sudo_user)
                                                            }.delete_undef_values
                                                          }
){
  assert_private()

  unless $transport_options[$default_transport] or $config_hash {
    fail("You must specify transport options for '${default_transport}' in '\$transport_options'")
  }

  if $local_user {
    $_local_user = $local_user
    $_local_group = $local_group
    $_puppet_dir = "${local_home}/.puppetlabs"
    $_bolt_dir_mode = '0640'
    $_create_log_dir = true
  }
  else {
    $_local_user = 'root'
    $_local_group = 'root'
    $_puppet_dir = "${local_home}/puppetlabs"
    $_bolt_dir_mode = '0644'
    $_create_log_dir = false
  }

  $_bolt_dir = "${_puppet_dir}/bolt"

  exec { 'Create Local Bolt Home':
    command => "mkdir -p ${local_home}",
    path    => ['/bin','/usr/bin'],
    umask   => '022',
    unless  => "test -d ${local_home}"
  }

  file { $_puppet_dir:
    ensure  => 'directory',
    owner   => $_local_user,
    group   => $_local_group,
    mode    => $_bolt_dir_mode,
    require => Exec['Create Local Bolt Home']
  }

  file { $_bolt_dir:
    ensure => 'directory',
    owner  => $_local_user,
    group  => $_local_group,
    mode   => $_bolt_dir_mode
  }

  # Create the config file for bolt
  file { "${_bolt_dir}/bolt.yaml":
    ensure  => 'file',
    owner   => $_local_user,
    group   => $_local_group,
    mode    => $_bolt_dir_mode,
    content => epp("${module_name}/bolt_yaml.epp", {
        config_hash       => $config_hash,
        color             => $color,
        concurrency       => $concurrency,
        default_transport => $default_transport,
        format            => $format,
        hiera_config      => $hiera_config,
        inventoryfile     => $inventoryfile,
        log_console_level => $log_console_level,
        log_file_append   => $log_file_append,
        log_file_level    => $log_file_level,
        log_file          => $log_file,
        modulepath        => $modulepath,
        transport_options => $transport_options
      }
    )
  }

  # Configure hiera
  file { "${_bolt_dir}/data":
    ensure => 'directory',
    owner  => $_local_user,
    group  => $_local_group,
    mode   => $_bolt_dir_mode
  }

  file { "${_bolt_dir}/hiera.yaml":
    ensure  => 'file',
    owner   => $_local_user,
    group   => $_local_group,
    mode    => $_bolt_dir_mode,
    replace => false,
    content => file("${module_name}/hiera.yaml")
  }

  # Ensure the directory for the log files exists
  $_log_dir = dirname($log_file)
  exec { 'Create Bolt Log Dir':
    command => "mkdir -p ${_log_dir}",
    path    => ['/bin','/usr/bin'],
    umask   => '022',
    unless  => "test -d ${_log_dir}"
  }

  if $_create_log_dir {
    file { $_log_dir:
      ensure => 'directory',
      owner  => $_local_user,
      group  => $_local_group,
      mode   => $_bolt_dir_mode
    }
  }

  # Create the config file for analytics
  file { "${_bolt_dir}/analytics.yaml":
    ensure => 'file',
    owner  => $_local_user,
    group  => $_local_group,
    mode   => $_bolt_dir_mode
  }

  # Ensure analytics are correctly enabled or disabled
  if $disable_analytics {
    file_line { 'analytics_yaml':
      ensure => present,
      path   => "${_bolt_dir}/analytics.yaml",
      line   => "disabled: ${disable_analytics}"
    }
  } else {
    file_line { 'analytics_yaml':
      ensure            => absent,
      path              => "${_bolt_dir}/analytics.yaml",
      match             => '^disabled:*',
      match_for_absence => true
    }
  }
}
