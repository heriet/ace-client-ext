
module AceClient
  module Niftycloud
    module Computing
      def instances
        response = self.action('DescribeInstances', {})
        begin
          items = [response['DescribeInstancesResponse']['reservationSet']['item']].flatten
          items.map{|item| item['instancesSet']['item'] }.flatten
        rescue
          []
        end
      end

      def items(options)
         response = self.action(options[:action], {})
         [response[options[:action] + 'Response'][options[:key]]['item']].flatten rescue []
      end

      {
        :regions => {:action => 'DescribeRegions', :key => 'regionInfo'},
        :availability_zones => {:action => 'DescribeAvailabilityZones', :key => 'availabilityZoneInfo'},
        :volumes => {:action => 'DescribeVolumes', :key => 'volumeSet'},
        :key_pairs => {:action => 'DescribeKeyPairs', :key => 'keySet'},
        :images => {:action => 'DescribeImages', :key => 'imagesSet'},
        :security_groups => {:action => 'DescribeSecurityGroups', :key => 'securityGroupInfo'},
        :ssl_certificates => {:action => 'DescribeSSLCertificates', :key => 'certsSet'},
        :addresses => {:action => 'DescribeAddresses', :key => 'addressesSet'},
        :uploads => {:action => 'DescribeUploads', :key => 'uploads'},
      }.each do |method, options|
        define_method method do
          items(:action => options[:action], :key => options[:key])
        end
      end

      def load_balancers
        response = self.action('DescribeLoadBalancers', {})
        [response['DescribeLoadBalancersResult']['LoadBalancerDescriptions']['member']].flatten rescue []
      end

      def security_group_rules
      end

      def find_instance_by_id(instance_id)
        response = self.action('DescribeInstances', {'InstanceId.1' => instance_id})
        response['DescribeInstancesResponse']['reservationSet']['item']['instancesSet']['item'] rescue nil
      end

      def stop_instances
        until instances.all? {|instance| instance['instanceState']['name'] != 'running'} do
          instances.each do |instance|
            if instance['instanceState']['name'] != 'stopped'
              self.action('StopInstances', {'InstanceId.1' => instance['instanceId']})
            end
          end
          sleep 5
        end
      end

      def delete_instances
        until instances.empty? do
          instances.each do |instance|
            self.action('TerminateInstances', {'InstanceId.1' => instance['instanceId']})
          end
          uploads.each do |upload|
            self.action('CancelUpload', {'ConversionTaskId' => upload['conversionTaskId']})
          end
          sleep 5
        end
      end

      def delete_key_pairs
        key_pairs.each do |key_pair|
          self.action('DeleteKeyPair', {'KeyName' => key_pair['keyName']})
        end
      end

      def find_security_group_by_name(name)
        response = self.action('DescribeSecurityGroups', {'GroupName.1' => name})
        response['DescribeSecurityGroupsResponse']['securityGroupInfo']['item'] rescue nil
      end

      def wait_security_group_status(name, status)
        loop do
          group = find_security_group_by_name(name)
          break if group['groupStatus'] == status
          sleep 1
        end
      end

      def delete_security_group_rules
        security_groups.each do |group|
          rules = [group['ipPermissions']['item']].flatten rescue []
          next if rules.empty?
          rules.each do |rule|
            hash = {}
            hash["IpPermissions.1.IpProtocol"] = rule['ipProtocol']
            hash["IpPermissions.1.FromPort"] = rule['fromPort'] if rule['fromPort']
            hash["IpPermissions.1.ToPort"] = rule['toPort'] if rule['toPort']
            hash["IpPermissions.1.InOut"] = rule['inOut'] if rule['inOut']
            if rule.key?('ipRanges')
              hash["IpPermissions.1.IpRanges.1.CidrIp"] = rule['ipRanges']['item']['cidrIp'] # TODO: can't delete cidr ip rules
            elsif rule.key?('groups')
              hash["IpPermissions.1.Groups.1.GroupName"] = rule['groups']['item']['groupName']
            end
            hash['GroupName'] = group['groupName']
            self.action('RevokeSecurityGroupIngress', hash)
            wait_security_group_status(group['groupName'], 'applied')
          end
        end
      end 

      def delete_security_groups
        until security_groups.empty? do
          security_groups.each do |group|
            self.action('DeleteSecurityGroup', 'GroupName' => group['groupName'])
          end
          sleep 5
        end
      end 

      def delete_load_balancers
        # not implemented yet
      end

      def delete_volumes
        # not implemented yet
      end
    
      def delete_resources
        stop_instances
        delete_instances 
        delete_key_pairs
        delete_security_group_rules
        delete_security_groups
        delete_load_balancers
        delete_volumes
      end
    end
  end
end