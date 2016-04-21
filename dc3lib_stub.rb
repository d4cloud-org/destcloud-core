# coding: utf-8

require 'json'
require 'rest-client'

$interfaces_rt1 = {
                   "output" =>
                     {
                      "interface" =>
                        [{
                          "name" => "eth0",
                          "description" => "router 1/0",
                          "mac-address" => "11:22:33:44:55:66",
                          "physical" => true,
                          "ipv4-address" => ["192.168.10.1/24"],
                          "admin-status" => true
                         },{
                          "name" => "eth1",
                          "description" => "router 1/1",
                          "mac-address" => "11:22:33:44:55:66",
                          "physical" => true,
                          "ipv4-address" => ["192.168.12.1/24"],
                          "admin-status" => true
                           }
                        ]
                     }
                  }
$interfaces_rt2 = {
                   "output" =>
                     {
                      "interface" =>
                        [{
                          "name" => "eth0",
                          "description" => "router 1/0",
                          "mac-address" => "11:22:33:44:55:66",
                          "physical" => true,
                          "ipv4-address" => ["192.168.10.2/24"],
                          "admin-status" => true
                         },{
                          "name" => "eth1",
                          "description" => "router 1/1",
                          "mac-address" => "11:22:33:44:55:66",
                          "physical" => true,
                          "ipv4-address" => ["192.168.11.1/24"],
                          "admin-status" => true
                           }
                        ]
                     }
                  }
$interfaces_rt3 = {
                   "output" =>
                     {
                      "interface" =>
                        [{
                          "name" => "eth0",
                          "description" => "router 1/0",
                          "mac-address" => "11:22:33:44:55:66",
                          "physical" => true,
                          "ipv4-address" => ["192.168.11.2/24"],
                          "admin-status" => true
                         },{
                          "name" => "eth1",
                          "description" => "router 1/1",
                          "mac-address" => "11:22:33:44:55:66",
                          "physical" => true,
                          "ipv4-address" => ["192.168.12.2/24"],
                          "admin-status" => true
                           }
                        ]
                     }
                  }

class DC3Lib
    def initialize
    end
    
    def get_interfaces(ipaddr)
        # name
        # description
        # mac-address
        # physical
        # ipv4-address (addr/prefix)
        # ipv6-address (addr/prefix)
        # admin-status
        # oper-status
        # vlan-id
        # parent-device
        p "RESTCONF: get_interfaces to #{ipaddr}"
        case ipaddr
        when "192.168.0.1" then
            return $interfaces_rt1.to_json
        when "192.168.0.2" then
            return $interfaces_rt2.to_json
        when "192.168.0.3" then
            return $interfaces_rt3.to_json
        end
    end

    def failure_action_port_down(ipaddr = "127.0.0.1", iface = "")
        p "RESTCONF: port down of #{ipaddr} iface #{iface}"
        return ""
    end

    def failure_action_all_loss(ipaddr = "127.0.0.1", iface = "", direction="both")
        ret = RestClient.post("http://#{ipaddr}/restconf/operations/destcloud3:failure-action",
                              { "input" => { "interface" => iface,
                                            "action" => {"all-lose" => [],
                                                         "direction" => direction}}}.to_json,
                              :content_type => :json)
        if ret.code != 200 then
            return nil
        end
        result = JSON.parse (ret.to_s)
        uuid = result['output']['uuid']
        return uuid
    end

    def failure_action_packet_loss(ipaddr = "127.0.0.1", iface = "", ratio = 0, direction = "both")
        ret = RestClient.post("http://#{ipaddr}/restconf/operations/destcloud3:failure-action",
                              { "input" => { "interface" => iface,
                                            "action" => {"packet-loss" => ratio,
                                                         "direction" => direction}}}.to_json,
                              :content_type => :json)
        if ret.code != 200 then
            return nil
        end
        result = JSON.parse (ret.to_s)
        uuid = result['output']['uuid']
        return uuid
    end

    def failure_action_route_change(ipaddr = "127.0.0.1", prefix ="", nexthop="")
        ret = RestClient.post("http://#{ipaddr}/restconf/operations/destcloud3:failure-action",
                              { "input" => {"action" => {"route-change" =>
                                                         {"prefix" => prefix,
                                                          "nexthop" => nexthop}}}}.to_json,
                              :content_type => :json)
        if ret.code != 200 then
            return nil
        end
        result = JSON.parse (ret.to_s)
        uuid = result['output']['uuid']
        return uuid
    end

    def failure_action_shaping(ipaddr = "127.0.0.1", iface = "")
        ret = RestClient.post("http://#{ipaddr}/restconf/operations/destcloud3:failure-action",
                              { "input" => { "interface" => iface,
                                            "action" => {"port-down" => []}}}.to_json,
                              :content_type => :json)
        if ret.code != 200 then
            return nil
        end
        result = JSON.parse (ret.to_s)
        uuid = result['output']['uuid']
        return uuid
    end

    def failure_action_delay(ipaddr = "127.0.0.1", iface = "")
        ret = RestClient.post("http://#{ipaddr}/restconf/operations/destcloud3:failure-action",
                              { "input" => { "interface" => iface,
                                            "action" => {"port-down" => []}}}.to_json,
                              :content_type => :json)
        if ret.code != 200 then
            return nil
        end
        result = JSON.parse (ret.to_s)
        uuid = result['output']['uuid']
        return uuid
    end

    def failure_action(ipaddr = "127.0.0.1", iface = "")
        return uuid
    end

    def recover(ipaddr = "127.0.0.1", uuid)
        ret = RestClient.post("http://#{ipaddr}/restconf/operations/destcloud3:recovery",
                              { "input" => { "uuid" => uuid} }.to_json,
                              :content_type => :json)
        return ret
    end

    def set_interface_state(ipaddr = "127.0.0.1", iface = "", state = "up")
        ret = RestClient.post("http://#{ipaddr}/restconf/operations/destcloud3:set-interface-state",
                              { "input" => { "interface" => iface,
                                            "state" => state} }.to_json,
                              :content_type => :json)
        return ret
    end
end

