test_name 'defined should create an entry in filesystem table'

confine :except, platform: ['windows']
confine :except, platform: %r{osx} # See PUP-4823
confine :except, platform: %r{solaris} # See PUP-5201
confine :except, platform: %r{^eos-} # Mount provider not supported on Arista EOS switches
confine :except, platform: %r{^cisco_} # See PUP-5826
confine :except, platform: %r{^huawei} # See PUP-6126

tag 'audit:low',
    'audit:refactor',  # Use block style `test_name`
    'audit:acceptance' # Could be done at the integration (or unit) layer though
# actual changing of resources could irreparably damage a
# host running this, or require special permissions.

require 'puppet/acceptance/mount_utils'
extend Puppet::Acceptance::MountUtils

name = "pl#{rand(999_999).to_i}"

agents.each do |agent|
  fs_file = filesystem_file(agent)
  fs_type = filesystem_type(agent)

  teardown do
    # (teardown) restore the fstab file
    on(agent, "mv /tmp/fs_file_backup #{fs_file}", acceptable_exit_codes: (0..254))
    # (teardown) umount disk image
    on(agent, "umount /#{name}", acceptable_exit_codes: (0..254))
    # (teardown) delete disk image
    on(agent, "rm /tmp/#{name}", acceptable_exit_codes: (0..254))
    # (teardown) delete mount point
    on(agent, "rm -fr /#{name}", acceptable_exit_codes: (0..254))
  end

  #------- SETUP -------#
  step "(setup) backup #{fs_file} file"
  on(agent, "cp #{fs_file} /tmp/fs_file_backup", acceptable_exit_codes: [0, 1])

  #------- TESTS -------#
  step 'create a mount with puppet (defined)'
  args = ['ensure=defined',
          "fstype=#{fs_type}",
          "device='/tmp/#{name}'"]
  on(agent, puppet_resource('mount', "/#{name}", args))

  step 'verify entry in filesystem table'
  on(agent, "cat #{fs_file}")  do |_res|
    fail_test "didn't find the mount #{name}" unless stdout.include? name.to_s
  end
end