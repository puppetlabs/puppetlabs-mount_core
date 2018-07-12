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

      it 'creates an entry in the filesystem table and mounts it' do
        step '(setup) create mount point'
        on(agent, "mkdir /#{name}", acceptable_exit_codes: [0, 1])

        step '(setup) create new filesystem to be mounted'
        MountUtils.create_filesystem(agent, name)

        step 'create a mount with puppet (mounted)'
        args = if agent['platform'] =~ %r{aix}
                 ['ensure=mounted',
                  "fstype=#{fs_type}",
                  "options='log=/dev/hd8'",
                  "device=/dev/#{name}"]
               else
                 ['ensure=mounted',
                  "fstype=#{fs_type}",
                  'options=loop',
                  "device=/tmp/#{name}"]
               end
        on(agent, puppet_resource('mount', "/#{name}", args))

        step 'verify entry in filesystem table'
        on(agent, "cat #{fs_file}") do |result|
          fail_test "didn't find the mount #{name}" unless result.stdout.include?(name)
        end

        step 'verify entry is mounted'
        on(agent, 'mount') do |result|
          fail_test "didn't find the mount #{name} mounted" unless result.stdout.include?(name)
        end
      end
    end
  end
end
