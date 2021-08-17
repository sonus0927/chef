return unless node.read('chef_guid')

alcon_logs_file = if platform?('windows')
                    'C:/chef/alcon_logs/result_summary-*.txt'
                  else
                    '/etc/chef/alcon_logs/result_summary-*.txt'
                  end

automate = obtain_data_bag_item('cookbook_credentials', 'automate', type: 'data_bag')
thyid = automate['thyid']

if platform?('windows')
  if !File.exist?("C:/install/#{node['hostname']}_ASIR.txt") && !File.exist?("C:/install/#{node['hostname']}_ASIR_COPIED.txt")
    alcon_node_reporter 'Create Report' do
      api_token obtain_thycotic_item(thyid, 'password', type: 'thycotic').to_s
      automate_server automate['automate_server']
      sensitive true
      only_if { ::Dir.glob(alcon_logs_file).empty? }
    end
  end
  if File.exist?("C:/install/#{node['hostname']}_ASIR.txt") && !File.exist?("C:/install/#{node['hostname']}_ASIR_COPIED.txt")
    domain_creds = obtain_data_bag_item('cookbook_credentials', 'ASIR', type: 'data_bag')
    domain_thyid = domain_creds['thyid']
    domain_user = obtain_thycotic_item(domain_thyid, 'username', type: 'thycotic')
    domain_passwd = obtain_thycotic_item(domain_thyid, 'password', type: 'thycotic')
    domain_domain = obtain_thycotic_item(domain_thyid, 'domain', type: 'thycotic')

    # Upload the ASIR details to the SNOW ticket

    include_recipe 'cb_int_anyos_snow::add_asir'

    powershell_script 'map_share_copy' do
      code <<-EOH
      echo 'Running ASIR move and rename'
      $user = "#{domain_user}@#{domain_domain}"
      $pwd = '#{domain_passwd.gsub(%('), %(' + "'" + '))}'
      $net = new-object -ComObject WScript.Network
      $net.MapNetworkDrive("Q:", "#{domain_creds['location']}", $false, $user, $pwd)
      copy C:\\install\\#{node['hostname']}_ASIR.txt Q:\\
      Copy-Item "C:\\install\\#{node['hostname']}_ASIR.txt" -Destination "C:\\install\\#{node['hostname']}_ASIR_COPIED.txt"
      echo 'Finished running ASIR move and rename'
      Net use Q: /delete
      EOH
      only_if { ::File.exist?("C:/install/#{node['hostname']}_ASIR.txt") }
    end
  end
  if File.exist?("C:/install/#{node['hostname']}_ASIR.txt") && File.exist?("C:/install/#{node['hostname']}_ASIR_COPIED.txt")
    powershell_script 'map_share_copy' do
      code <<-EOH
      Remove-Item "C:\\install\\#{node['hostname']}_ASIR.txt"
      EOH
    end
  end
else
  checkfile = '/etc/chef/alcon_logs/result_summary_complete.txt'
  unless File.exist?(checkfile)
    alcon_node_reporter 'Create Report' do
      api_token obtain_thycotic_item(thyid, 'password', type: 'thycotic').to_s
      automate_server automate['automate_server']
      sensitive true
      only_if { ::Dir.glob(alcon_logs_file).empty? }
    end
  end
end
