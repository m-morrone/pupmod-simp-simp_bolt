require 'spec_helper_acceptance'

test_name 'install tpm simulators'

describe 'install tpm_simulators' do

  # Implement any workarounds that are needed to run as service
  def implement_workarounds(hirs_host)
    # workaround for dbus config file mismatch error:
    # "dbus[562]: [system] Unable to reload configuration: Configuration file
    #  needs one or more <listen> elements giving addresses"
    on hirs_host, 'systemctl restart dbus'
  end

  # starts tpm2sim service
  def start_tpm2sim_on(hirs_host)
    on hirs_host, 'yum install -y tpm2-tools'
    on hirs_host, 'runuser tpm2sim --shell /bin/sh -c ' \
      '"cd /tmp; nohup /usr/local/bin/tpm2-simulator &> /tmp/tpm2-simulator.log &"', \
      pty: true, run_in_parallel: true
  end

  def config_abrmd_for_tpm2sim_on(hirs_host)
    on hirs_host, 'mkdir -p /etc/systemd/system/tpm2-abrmd.service.d'
    # Configure the TAB/RM to talk to the TPM2 simulator
    extra_file=<<-SYSTEMD.gsub(/^\s*/,'')
    [Service]
    ExecStart=
    ExecStart=/sbin/tpm2-abrmd -t socket
    SYSTEMD
    create_remote_file hirs_host, '/etc/systemd/system/tpm2-abrmd.service.d/override.conf', extra_file
    on hirs_host, 'systemctl daemon-reload'
    on hirs_host, 'systemctl list-unit-files | grep tpm2-abrmd ' \
      + '&& systemctl restart tpm2-abrmd ' \
      + %q[|| echo "tpm2-abrmd.service not restarted because it doesn't exist"]
  end

  # start the tpm2sim and override tpm2-abrmd's systemd config use it
  # assumes the tpm2sim has been installed on the hosts
  def configure_tpm2_0_tools(hirs_host)
    start_tpm2sim_on(hirs_host)
    config_abrmd_for_tpm2sim_on(hirs_host)
  end

  # This is a helper to get the status of the TPM so it can be compared against the
  # the expected results.
  def get_tpm2_status(hirs_host)
      stdout = on(hirs_host, 'facter -p -y tpm2 --strict').stdout
      fact = YAML.safe_load(stdout)['tpm2']
      tpm2_status = fact['tpm2_getcap']['properties-variable']['TPM_PT_PERSISTENT']
      [tpm2_status['ownerAuthSet'],tpm2_status['endorsementAuthSet'],tpm2_status['lockoutAuthSet']]
  end

  # starts tpm 1.2 simulator services 
  # Per the README file included with the source code, procedures for starting the tpm are:
  #   Start the TPM in another shell after setting its environment variables
  #     (TPM_PATH,TPM_PORT)
  #     > cd utils
  #     > ./tpmbios
  #   Kill the TPM in the other shell and restart it
  def start_tpm_1_2_sim(hirs_host)
    os = fact_on(hirs_host,'operatingsystemmajrelease')
    on hirs_host, 'yum install -y trousers gcc tpm-tools'
    if os.eql?('7')
      on hirs_host, 'systemctl start tpm12-simulator'
      on hirs_host, 'systemctl start tpm12-tpmbios'
      on hirs_host, 'systemctl restart tpm12-simulator'
      on hirs_host, 'systemctl restart tpm12-tpmbios'
      on hirs_host, 'systemctl start tpm12-tpminit'
      on hirs_host, 'systemctl start tpm12-tcsd'
    else os.eql?('6')
      on hirs_host, 'service tpm12-simulator start '
      on hirs_host, 'service tpm12-tpmbios start '
      on hirs_host, 'service tpm12-simulator restart '
      on hirs_host, 'service tpm12-tpmbios start '
      on hirs_host, 'service tpm12-tpminit start '
      on hirs_host, 'service tpm12-tcsd start '
    end
  end

  context 'on a hirs host' do
    hosts_with_role(hosts, 'hirs').each do |hirs_host|

    # Using puppet_apply as a helper
      it 'should work with no errors' do
        install_pre_suite_rpms(hirs_host)
        if hirs_host.host_hash[:roles].include?('tpm_2_0')
          implement_workarounds(hirs_host)
          configure_tpm2_0_tools(hirs_host)
        else
          start_tpm_1_2_sim(hirs_host)
        end

      end
    end
  end
end
