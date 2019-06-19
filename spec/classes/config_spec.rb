require 'spec_helper'
require 'rspec-puppet-facts'

describe 'simp_bolt::controller::config' do
  shared_examples_for "a structured module" do
    it { is_expected.to compile.with_all_deps }
    it { is_expected.to create_class('simp_bolt::controller::config') }
  end

  context 'supported operating systems' do
    on_supported_os.each do |os, os_facts|
      context "on #{os}" do

        let(:facts) do
          os_facts
        end

        before(:each) do
          # Mask 'assert_private' for testing
          Puppet::Parser::Functions.newfunction(:assert_private, :type => :rvalue) { |args| }
        end

        # Requires variable set in init.pp, so including here
        let(:pre_condition) { 'include simp_bolt' }

        context 'with no transport options or config hash' do
          let(:params) {{ :default_transport => 'local' }}
          it "is expected to fail" do
            expect { catalogue }.to raise_error Puppet::PreformattedError, /You must specify transport options/
          end
        end

        context 'with default parameters' do
          let(:params) {{ }}
          it_behaves_like "a structured module"
          it { is_expected.to contain_exec('Create Local Bolt Home').with_command('mkdir -p /var/local/simp_bolt') }
          it { is_expected.to create_file('/var/local/simp_bolt/puppetlabs') }
          it { is_expected.to create_file('/var/local/simp_bolt/puppetlabs/bolt') }
          it { is_expected.to create_file('/var/local/simp_bolt/puppetlabs/bolt/bolt.yaml') }
          it { is_expected.to create_file('/var/local/simp_bolt/puppetlabs/bolt/data') }
          it { is_expected.to create_file('/var/local/simp_bolt/puppetlabs/bolt/hiera.yaml') }
          it { is_expected.to create_file('/var/local/simp_bolt/puppetlabs/bolt/analytics.yaml') }
          it { is_expected.to create_file_line('analytics_yaml') }
          it { is_expected.to contain_exec('Create Bolt Log Dir').with_command('mkdir -p /var/log/puppetlabs/bolt') }
          it { is_expected.not_to create_file('/var/log/puppetlabs/bolt') }
        end

        context 'with a local user specified' do
          let(:params) {{
            :local_user  => 'user',
            :local_group => 'user',
            :local_home  => '/home/user'
          }}
          it_behaves_like "a structured module"
          it { is_expected.to contain_exec('Create Local Bolt Home').with_command('mkdir -p /home/user') }
          it { is_expected.to create_file('/home/user/.puppetlabs') }
          it { is_expected.to create_file('/home/user/.puppetlabs/bolt') }
          it { is_expected.to create_file('/home/user/.puppetlabs/bolt/bolt.yaml') }
          it { is_expected.to create_file('/home/user/.puppetlabs/bolt/data') }
          it { is_expected.to create_file('/home/user/.puppetlabs/bolt/hiera.yaml') }
          it { is_expected.to create_file('/home/user/.puppetlabs/bolt/analytics.yaml') }
          it { is_expected.to create_file_line('analytics_yaml') }
          it { is_expected.to contain_exec('Create Bolt Log Dir').with_command('mkdir -p /var/log/puppetlabs/bolt') }
          it { is_expected.to create_file('/var/log/puppetlabs/bolt') }
        end

        context 'with a config hash' do
          let(:header){
            <<-EOM
# This file managed by puppet.
# Any changes that you make will be reverted on the next puppet run.
#
# Bolt configuration file
# https://puppet.com/docs/bolt/1.x/bolt_configuration_options.html
            EOM
          }

          let(:params) {{
            :config_hash       => {
              'param1' => 'string',
              'param2' => true,
              'param3' => [ 'array thing' ],
              'param4' => { 'hashy' => 'mchashface' }
            },
            :default_transport => 'local'
          }}
          it_behaves_like "a structured module"
          it { is_expected.to create_file('/var/local/simp_bolt/puppetlabs/bolt/bolt.yaml').with_content(
            header + params[:config_hash].to_yaml + "\n"
          ) }
        end
      end
    end
  end
end
