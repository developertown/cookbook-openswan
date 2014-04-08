#
# Cookbook Name:: openswan
# Recipe:: default
#
# Copyright 2014, DeveloperTown, LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#


# Ensure Openswan is installed
package "openswan"
service "ipsec"

# Ensure kernel NAT parameters are set properly
cookbook_file "nat-sysctl.conf" do
  mode 0644
  owner "root"
  group "root"
  path "/etc/sysctl.d/90-nat.conf"
end

execute "/sbin/sysctl -p /etc/sysctl.d/90-nat.conf"


# Ensure kernel parameters for OpenSwan are set properly
cookbook_file "openswan-sysctl.conf" do
  mode 0644
  owner "root"
  group "root"
  path "/etc/sysctl.d/91-openswan.conf"
end

execute "/sbin/sysctl -p /etc/sysctl.d/91-openswan.conf"

# Setup NAT rules
execute "Setup iptables for NAT" do
  command "/sbin/iptables  -t nat -A POSTROUTING -o eth0 -s 0.0.0.0/0 -j MASQUERADE"
  not_if "/sbin/iptables -t nat -C POSTROUTING -o eth0 -s 0.0.0.0/0 -j MASQUERADE"
end

node[:openswan][:peers].each do |peer|

  template "/etc/ipsec.d/#{peer[:name]}.conf" do
    source "site_connection.conf.erb"
    mode 0644
    owner "root"
    group "root"
    notifies :reload, "service[ipsec]", :delayed
    variables({
      :name => peer[:name],
      :local_ip => node[:ipaddress],
      :elastic_ip => node[:openswan][:my_elastic_ip],
      :their_external_ip => peer[:their_external_ip],
      :their_inside_subnet => peer[:their_inside_subnet],
      :ike => peer[:ike],
      :ikelifetime => peer[:ikelifetime],
      :phase2alg => peer[:phase2alg],
      :salifetime => peer[:salifetime]
    })
  end

  bash "Adding key to secrets for #{peer[:name]}" do
    code <<-EOH
      echo "##{peer[:name]}" >> /etc/ipsec.secrets
      echo "#{peer[:their_external_ip]} %any: PSK \"#{peer[:shared_secret]}\"" >> /etc/ipsec.secrets
    EOH
    notifies :reload, "service[ipsec]", :delayed

    only_if { (File.readlines "/etc/ipsec.secrets").grep(/^##{Regexp.quote(peer[:name])}/).empty? }
  end

end

