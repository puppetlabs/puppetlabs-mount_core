require 'spec_helper_acceptance'

require 'mount_utils'

RSpec.context 'when managing mounts' do
  agents.each do |agent|
    context "on #{agent}" do
      include_context('mount context', agent)

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
