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
      let(:backup) { agent.tmpfile('mount-modify') }
      let(:name) { "pl#{rand(999_999).to_i}" }

      before(:each) do
        on(agent, "cp #{fs_file} #{backup}", acceptable_exit_codes: [0, 1])
      end

      after(:each) do
        # umount disk image
        on(agent, "umount /#{name}", acceptable_exit_codes: (0..254))
        # delete disk image
        if agent['platform'] =~ %r{aix}
          on(agent, "rmlv -f #{name}", acceptable_exit_codes: (0..254))
        else
          on(agent, "rm /tmp/#{name}", acceptable_exit_codes: (0..254))
        end
        # delete mount point
        on(agent, "rm -fr /#{name}", acceptable_exit_codes: (0..254))
        # restore the fstab file
        on(agent, "mv #{backup} #{fs_file}", acceptable_exit_codes: (0..254))
      end

      it 'finds an existing filesystem table entry' do
        step '(setup) add entry to filesystem table'
        MountUtils.add_entry_to_filesystem_table(agent, name)

        step 'verify mount with puppet'
        on(agent, puppet_resource('mount', "/#{name}")) do |result|
          fail_test "didn't find the mount #{name}" unless result.stdout =~ %r{'/#{name}':\s+ensure\s+=>\s+'unmounted'}
        end
      end
    end
  end
end
