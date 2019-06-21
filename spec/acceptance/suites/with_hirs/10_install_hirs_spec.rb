require 'spec_helper_acceptance'

test_name 'hirs_provisioner class'

describe 'hirs_provisioner class' do

  let(:run_cmd) {'runuser simp_bolt -l -c '}

  #install an aca for the provisioners to talk to
  def setup_aca(aca)
    on aca, 'yum install -y mariadb-server openssl tomcat java-1.8.0 rpmdevtools coreutils initscripts chkconfig sed grep firewalld policycoreutils'
    on aca, 'yum install -y HIRS_AttestationCA'
    sleep(10)
  end

  #configure site.yaml and hiera
  def config_site_and_hiera(_boltserver)
    on _boltserver, 'runuser simp_bolt -l -c "printf \"mod \'puppetlabs-stdlib\', \'5.2.0\'\nmod \'simp-simplib\', \'3.13.0\'\nmod \'simp/hirs_provisioner\', git: \'https://github.com/simp/pupmod-simp-hirs_provisioner.git\', ref: \'master\'\" > /var/local/simp_bolt/.puppetlabs/bolt/Puppetfile"'
    on _boltserver, 'runuser simp_bolt -l -c "bolt puppetfile install"'
    on _boltserver, 'runuser simp_bolt -l -c "printf -- \"---\nhirs_provisioner::config::aca_fqdn: aca\" > /var/local/simp_bolt/.puppetlabs/bolt/data/common.yaml"'
    on _boltserver, 'runuser simp_bolt -l -c "printf \"include hirs_provisioner\" > /var/local/simp_bolt/.puppetlabs/bolt/site.pp"'
  end

  context 'set up aca' do
    it 'should start the aca server' do
      aca_host = only_host_with_role( hosts, 'aca' )
      setup_aca(aca_host)
    end
  end

  context 'on specified hirs systems' do
    it 'should install hirs_provisioner' do
      _boltserver = hosts_with_role( hosts, 'boltserver' ).first 
      config_site_and_hiera(_boltserver)
      hosts_with_role( hosts, 'hirs' ).each do |hirs_host|
        on _boltserver, "runuser simp_bolt -l -c \"bolt apply /var/local/simp_bolt/.puppetlabs/bolt/site.pp --nodes '#{hirs_host}' --no-host-key-check\""
      end
    end
  end
end
