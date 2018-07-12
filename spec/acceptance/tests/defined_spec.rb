require 'spec_helper_acceptance'

require 'mount_utils'

# confine :except, platform: ['windows']
# confine :except, platform: %r{osx} # See PUP-4823
# confine :except, platform: %r{solaris} # See PUP-5201
# confine :except, platform: %r{^eos-} # Mount provider not supported on Arista EOS switches
# confine :except, platform: %r{^cisco_} # See PUP-5826
# confine :except, platform: %r{^huawei} # See PUP-6126

RSpec.context 'when managing mounts' do
  agents.each do |agent|
    context "on #{agent}" do
      let(:fs_file) { MountUtils.filesystem_file(agent) }
      let(:fs_type) { MountUtils.filesystem_type(agent) }
      let(:backup) { agent.tmpfile('mount-defined') }
      let(:name) { "pl#{rand(999_999).to_i}" }

      before(:each) do
        # (teardown) restore the fstab file
        on(agent, "mv #{backup} #{fs_file}", acceptable_exit_codes: (0..254))
        # (teardown) umount disk image
        on(agent, "umount /#{name}", acceptable_exit_codes: (0..254))
        # (teardown) delete disk image
        on(agent, "rm /tmp/#{name}", acceptable_exit_codes: (0..254))
        # (teardown) delete mount point
        on(agent, "rm -fr /#{name}", acceptable_exit_codes: (0..254))
      end

      after(:each) do
        step "restore #{fs_file} file from backup #{backup}"
        on(agent, "mv #{backup} #{fs_file}", acceptable_exit_codes: (0..254))
      end

      it 'defines a mount entry' do
        step 'creates a mount'
        args = ['ensure=defined',
                "fstype=#{fs_type}",
                "device='/tmp/#{name}'"]
        on(agent, puppet_resource('mount', "/#{name}", args))

        step 'verify entry in filesystem table'
        on(agent, "cat #{fs_file}")  do |result|
          fail_test "didn't find the mount #{name}" unless result.stdout.include?(name)
        end
      end
    end
  end
end
