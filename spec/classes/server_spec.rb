require 'spec_helper'

describe 'rsync::server' do
  context 'supported operating systems' do
    on_supported_os.each do |os, os_facts|
      let(:facts) { os_facts }

      context "on #{os}" do
        context 'with default parameters' do
          it { is_expected.to compile.with_all_deps }
          it { is_expected.to create_class('rsync') }
          it { is_expected.to create_class('stunnel') }
          it { is_expected.to create_stunnel__connection('rsync').with({
            :connect      => [873],
            :accept       => '0.0.0.0:8730',
            :client       => false,
            :trusted_nets => ['1.2.3.4','5.6.7.8']
            })
          }
          it { is_expected.to create_concat('/etc/rsyncd.conf').that_notifies('Service[rsyncd]') }
          it { is_expected.to create_service('rsyncd').that_subscribes_to('Service[stunnel]') }
        end

        context 'no_stunnel' do
          let(:params){{ :stunnel => false }}

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to_not create_class('stunnel') }
          it { is_expected.to create_concat('/etc/rsyncd.conf').that_notifies('Service[rsyncd]') }
          it { is_expected.to create_service('rsyncd') }
          it { is_expected.to create_service('rsyncd').without_subscribes }
        end
      end
    end
  end
end
