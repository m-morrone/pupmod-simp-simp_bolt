require 'spec_helper_acceptance'

test_name 'simp_bolt class'

describe 'simp_bolt class' do
  allowed_from       = hosts_with_role( hosts, 'boltserver' )
  allowed_from_fqdns = allowed_from.map { |host| fact_on(host, 'fqdn') }
  let(:manifest) {
    <<-EOS
      include 'simp_bolt'
    EOS
  }
  let(:files_dir) { File.join(File.dirname(__FILE__), 'files') }
  let(:ssh_authorized_key) {
['AAAAB3NzaC1yc2EAAAADAQABAAACAQDI9DPUsQXNTqU2nWShmMCnGOXPDYazX4yHFrI7Xw3p/r62Li6zaSSNuJ8varX24j8NNMK9EeYcQnrkEu+PE7kO7UTnat3AQFASAlnZTkqo4F/bQjoVEvVaZHaAupiiQYMJny+8R/0VrPGQGx3IR2ORuMs0nAZjjZK3pdmMNNi284Rox3qi9qCeQY0yO3sdyygRwtKyAJvOSwTVrTuYQrMVzWbWsbBk7wO27A7bwbaCZ/nZFzjwB+t3HTJ2t9ZSxCtH0tnvPUEtswZdVN+yAKwka8dyULvhnGtfc8wcA8OJoYmb5Sqh67QU+ofBRkj1I0F33VfEyrNME9q5jT0V2/uS5WJjUNPScBZeZjR60ZA791ZrmyAw9ybK55h8SNmZWi3/PyteaZnHVY4fe0M38MtHy2qh+vBp2o/aVIhGo/cWotQpZaPMnJeNzqlvNQXm04Rz+5BeOZBAOLH/TiJFXpEoNYLYPSy7p1Y22QKPoMmgjp5MiCvBhY1v60rHnogBOTor5rebD2R+KyVK6beLb/nABCoJNvquefE+fpo/5+zVr9IfCDnnTJLKtUuNetk6D0gl76bhsfiEsWz2r1ND7ihXjcv3z3v38V4mr8m3cmAuVU7mNYHZvwM5i55VNitS1qUiSkvccKBbnxa15e0YxXUfnq8PI/Yq2Iky/K4am/XMkw==','AAAAB3NzaC1yc2EAAAADAQABAAACAQDI9DPUsQXNTqU2nWShmMCnGOXPDYazX4yHFrI7Xw3p/r62Li6zaSSNuJ8varX24j8NNMK9EeYcQnrkEu+PE7kO7UTnat3AQFASAlnZTkqo4F/bQjoVEvVaZHaAupiiQYMJny+8R/0VrPGQGx3IR2ORuMs0nAZjjZK3pdmMNNi284Rox3qi9qCeQY0yO3sdyygRwtKyAJvOSwTVrTuYQrMVzWbWsbBk7wO27A7bwbaCZ/nZFzjwB+t3HTJ2t9ZSxCtH0tnvPUEtswZdVN+yAKwka8dyULvhnGtfc8wcA8OJoYmb5Sqh67QU+ofBRkj1I0F33VfEyrNME9q5jT0V2/uS5WJjUNPScBZeZjR60ZA791ZrmyAw9ybK55h8SNmZWi3/PyteaZnHVY4fe0M38MtHy2qh+vBp2o/aVIhGo/cWotQpZaPMnJeNzqlvNQXm04Rz+5BeOZBAOLH/TiJFXpEoNYLYPSy7p1Y22QKPoMmgjp5MiCvBhY1v60rHnogBOTor5rebD2R+KyVK6beLb/nABCoJNvquefE+fpo/5+zVr9IfCDnnTJLKtUuNetk6D0gl76bhsfiEsWz2r1ND7ihXjcv3z3v38V4mr8m3cmAuVU7mNYHZvwM5i55VNitS1qUiSkvccKBbnxa15e0Yq8PI/YqABogusKeyForTesting==']
  }
  let(:passwd) {'$6$0BVLUFTByfXbi4$OkGTJrGMkhr44IUHpWKss94af63UoLH3qab9Oikzj6GnscLPV18oKEDIIb3lYDAEI7bw7nYeJKzWc16OtkdiY1'}

  hosts_with_role( hosts, 'target' ).each do |host|
    context 'default parameters' do
      # Using puppet_apply as a helper
      # Module intentionally fails if both password and ssh_authorized_key are not defined
      # Will test that case in spec tests

      let(:target_hieradata) {
        <<-EOS
---
simp_bolt::bolt_target: true
simp_bolt::target::create_user: true
simp_bolt::target::user_password: #{passwd}
simp_bolt::target::user_allowed_from: #{allowed_from_fqdns}
simp_bolt::target::user_ssh_authorized_keys: #{ssh_authorized_key}
        EOS
      }
      it "should create the user simp_bolt and directory structure on #{host.name}" do
        set_hieradata_on(host, target_hieradata)
        apply_manifest_on(host, manifest, :catch_failures => true)
      end

      it 'should be idempotent' do
        set_hieradata_on(host, target_hieradata)
        apply_manifest_on(host, manifest, :catch_changes => true)
      end
    end
  end

  hosts_with_role( hosts, 'boltserver' ).each do |_boltserver|
    context 'configure bolt and servers' do

      let(:server_hieradata) {
        <<-EOS
---
simp_bolt::bolt_target: true
simp_bolt::bolt_controller: true
simp_bolt::target::create_user: true
simp_bolt::target::user_allowed_from: #{allowed_from_fqdns}
simp_bolt::target::user_password: #{passwd}
simp_bolt::target::user_ssh_authorized_keys: #{ssh_authorized_key}
simp_bolt::controller::local_user_name: simp_bolt
simp_bolt::controller::local_group_name: simp_bolt
simp_bolt::controller::local_user_home: /var/local/simp_bolt
        EOS
      }

      it "should install puppet bolt on #{_boltserver.name}" do
        scp_to(_boltserver, File.join(files_dir, 'id_rsa.example'), '/var/local/simp_bolt/.ssh/id_rsa')
        on(_boltserver, 'chown -R simp_bolt:simp_bolt /var/local/simp_bolt/.ssh/id_rsa')
        os = fact_on(_boltserver,'operatingsystemmajrelease')
        on(_boltserver, "rpm -Uvh https://yum.puppet.com/puppet5-release-el-#{os}.noarch.rpm")
        set_hieradata_on(_boltserver, server_hieradata)
        apply_manifest_on(_boltserver, manifest, :catch_failures => true)
      end

      let(:run_cmd) {'runuser simp_bolt -l -c '}
      let(:bolt_remote_cmd) {"touch /var/local/#{_boltserver}"}

      hosts_with_role( hosts, 'target' ).each do |host|
        it "should execute a command on #{host.name} system via bolt" do
          bolt_cmd="bolt command run '#{bolt_remote_cmd}' --nodes #{host.name} --no-host-key-check --sudo-password password"
          on(_boltserver, "#{run_cmd} \"#{bolt_cmd}\"")
          host.file_exist?("/var/local/#{_boltserver}")
        end
      end
    end
  end
end
