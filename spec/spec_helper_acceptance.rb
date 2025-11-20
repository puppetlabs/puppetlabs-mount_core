require 'beaker-rspec'
require 'beaker-puppet'
require 'beaker/module_install_helper'
require 'voxpupuli/acceptance/spec_helper_acceptance'

$LOAD_PATH << File.join(__dir__, 'acceptance/lib')

RSpec.configure do |c|
  def run_puppet_install_helper
    return unless ENV['PUPPET_INSTALL_TYPE'] == 'agent'
    if ENV['BEAKER_PUPPET_COLLECTION'].match? %r{/-nightly$/}
      # Workaround for RE-10734
      options[:release_apt_repo_url] = 'http://nightlies.puppet.com/apt'
      options[:win_download_url] = 'http://nightlies.puppet.com/downloads/windows'
      options[:mac_download_url] = 'http://nightlies.puppet.com/downloads/mac'
    end

    agent_sha = ENV['BEAKER_PUPPET_AGENT_SHA'] || ENV['PUPPET_AGENT_SHA']
    if agent_sha.nil? || agent_sha.empty?
      install_puppet_agent_on(hosts, options.merge(version:))
    else
      # If we have a development sha, assume we're testing internally
      dev_builds_url = ENV['DEV_BUILDS_URL'] || 'http://builds.delivery.puppetlabs.net'
      install_from_build_data_url('puppet-agent', "#{dev_builds_url}/puppet-agent/#{agent_sha}/artifacts/#{agent_sha}.yaml", hosts)
    end

    # XXX install_puppet_agent_on() will only add_aio_defaults_on when the
    # nodeset type == 'aio', but we don't want to depend on that.
    add_aio_defaults_on(hosts)
    add_puppet_paths_on(hosts)
  end

  c.before :suite do
    unless ENV['BEAKER_provision'] == 'no'
      hosts.each { |host| host[:type] = 'aio' }
      run_puppet_install_helper
      install_module_on(hosts)
      install_module_dependencies_on(hosts)
    end
  end
end

shared_context 'mount context' do |agent|
  let(:fs_file) { MountUtils.filesystem_file(agent) }
  let(:fs_type) { MountUtils.filesystem_type(agent) }
  let(:backup) { agent.tmpfile('mount-modify') }
  let(:name) { "pl#{rand(999_999).to_i}" }
  let(:name_w_slash) { "pl#{rand(999_999).to_i}\/" }
  let(:name_w_whitespace) { "pl#{rand(999).to_i} #{rand(999).to_i}" }

  before(:each) do
    on(agent, "cp #{fs_file} #{backup}", acceptable_exit_codes: [0, 1])
  end

  after(:each) do
    # umount disk image
    on(agent, "umount /#{name}", acceptable_exit_codes: (0..254))
    # delete disk image
    if agent['platform'].include?('aix')
      on(agent, "rmlv -f #{name}", acceptable_exit_codes: (0..254))
    else
      on(agent, "rm /tmp/#{name}", acceptable_exit_codes: (0..254))
    end
    # delete mount point
    on(agent, "rm -fr /#{name}", acceptable_exit_codes: (0..254))
    # restore the fstab file
    on(agent, "mv #{backup} #{fs_file}", acceptable_exit_codes: (0..254))
  end
end
