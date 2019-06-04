require 'spec_helper_acceptance'

test_name 'hirs_provisioner class'

describe 'hirs_provisioner class' do

  #create a local repo with the necessary HIRS rpms
  #this can be replaced later when the packages are signed and added to the extras repo
  def create_local_repo(hirs_host)
    os = fact_on(hirs_host,'operatingsystemmajrelease')
    hirs_host.install_package('createrepo')
    on hirs_host, 'mkdir /usr/local/repo'
    if os.eql?('7')
#      on hirs_host, 'cd /usr/local/repo; curl -L -O https://github.com/nsacyber/HIRS/releases/download/v1.0.2/HIRS_Provisioner_TPM_1_2-1.0.2-1541093721.d1bdf9.el7.noarch.rpm'
      scp_to(hirs_host, File.join(files_dir, 'HIRS_Provisioner_TPM_1_2-1.0.4-1558547257.cedc93.el7.noarch.rpm'), '/usr/local/repo/')
      scp_to(hirs_host, File.join(files_dir, 'HIRS_Provisioner_TPM_2_0-1.0.4-1558547257.cedc93.el7.x86_64.rpm'), '/usr/local/repo')
      on hirs_host, 'rpm --import http://download.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-7'
    else os.eql?('6')
#      on hirs_host, 'cd /usr/local/repo; curl -L -O https://github.com/nsacyber/HIRS/releases/download/v1.0.2/HIRS_Provisioner_TPM_1_2-1.0.2-1541093721.d1bdf9.el6.noarch.rpm'
      scp_to(hirs_host, File.join(files_dir, 'HIRS_Provisioner_TPM_1_2-1.0.4-1558547257.cedc93.el6.noarch.rpm'), '/usr/local/repo')
      on hirs_host, 'rpm --import http://download.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-6'
    end
#    on hirs_host, 'cd /usr/local/repo; curl -L -O https://github.com/nsacyber/HIRS/releases/download/v1.0.2/tpm_module-1.0.2-1541093721.d1bdf9.x86_64.rpm'
#    on hirs_host, 'cd /usr/local/repo; curl -L -O https://github.com/nsacyber/paccor/releases/download/v1.0.6r3/paccor-1.0.6-3.noarch.rpm'
    scp_to(hirs_host, File.join(files_dir, 'tpm_module-1.0.4-1558547257.cedc93.x86_64.rpm'), '/usr/local/repo')
    scp_to(hirs_host, File.join(files_dir, 'paccor-1.1.0-2.noarch.rpm'), '/usr/local/repo')
    on hirs_host, 'createrepo /usr/local/repo'
    on hirs_host, 'printf "[local.repo]\nname=local\nbaseurl=file:///usr/local/repo\nenabled=1\ngpgcheck=0" > /etc/yum.repos.d/local.repo'
  end

  #install an aca for the provisioners to talk to
  def setup_aca(aca)
    #on aca, 'curl -L -O https://github.com/nsacyber/HIRS/releases/download/v1.0.2/HIRS_AttestationCA-1.0.2-1541093721.d1bdf9.el7.noarch.rpm'
    scp_to(aca, File.join(files_dir, 'HIRS_AttestationCA-1.0.4-1558547257.cedc93.el7.noarch.rpm'), '/root')
    on aca, 'yum install -y mariadb-server openssl tomcat java-1.8.0 rpmdevtools coreutils initscripts chkconfig sed grep firewalld policycoreutils'
    on aca, 'yum localinstall -y HIRS_AttestationCA-1.0.4-1558547257.cedc93.el7.noarch.rpm'
    sleep(10)
  end

  #configure site.yaml and hiera
  def config_site_and_hiera(_boltserver)
    scp_to(_boltserver, File.join(files_dir, 'Puppetfile'), '/var/local/simp_bolt/.puppetlabs/bolt/Puppetfile')
    on _boltserver, 'bolt puppetfile install'
    scp_to(_boltserver, File.join(files_dir, 'hiera.yaml'), '/var/local/simp_bolt/.puppetlabs/bolt/hiera.yaml')
    on _boltserver, 'mkdir /var/local/simp_bolt/.puppetlabs/bolt/data'
    on _boltserver, 'printf "---\nhirs_provisioner::config:::aca_fqdn: aca" > /var/local/simp_bolt/.puppetlabs/bolt/data/common.yaml'
    on _boltserver, 'printf "include hirs_provisioner" > /var/local/simp_bolt/.puppetlabs/bolt/site.pp'
  end


  let(:files_dir) { File.join(File.dirname(__FILE__), 'files') }

  context 'set up aca' do
    it 'should start the aca server' do
      aca_host = only_host_with_role( hosts, 'aca' )
      setup_aca(aca_host)
    end
  end

  context 'with a tpm' do
    hosts_with_role(hosts, 'hirs').each do |hirs_host|
      it 'should create a local yum repo' do
        create_local_repo(hirs_host)
      end
    end
  end

  context 'on specified hirs systems' do
    hosts_with_role( hosts, 'boltserver' ).first do |_boltserver|
      it 'should install hirs_provisioner' do
        config_site_and_hiera(_boltserver)
        hosts_with_role( hosts, 'hirs' ).each do |hirs_host|
          on _boltserver, "bolt apply site.pp --nodes '#{hirs_host}' --no-host-key-check"
        end
      end
    end
  end
end
