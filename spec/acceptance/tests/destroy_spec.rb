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
      let(:backup) { agent.tmpfile('mount-destroy') }
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

      it 'deletes an entry in filesystem table and unmounts it' do
        step 'create mount point'
        on(agent, "mkdir /#{name}", acceptable_exit_codes: [0, 1])

        step 'create new filesystem to be mounted'
        MountUtils.create_filesystem(agent, name)

        step 'add entry to the filesystem table'
        MountUtils.add_entry_to_filesystem_table(agent, name)

        step 'mount entry'
        on(agent, "mount /#{name}")

        step 'verify entry exists in filesystem table'
        on(agent, "cat #{fs_file}") do |result|
          fail_test "did not find mount #{name}" unless result.stdout.include?(name)
        end

        step 'destroy a mount with puppet (absent)'
        on(agent, puppet_resource('mount', "/#{name}", 'ensure=absent'))

        step 'verify entry removed from filesystem table'
        on(agent, "cat #{fs_file}") do |result|
          fail_test "found the mount #{name}" if result.stdout.include?(name)
        end

        step 'verify entry is not mounted'
        on(agent, 'mount') do |result|
          fail_test "found the mount #{name} mounted" if result.stdout.include?(name)
        end
      end
    end
  end
end
