# coding: utf-8

require 'json'
require 'rest-client'
require 'base64'

class DC3Lib
    def initialize
        @auth = 'Basic ' + Base64.encode64( "admin:admin" ).chomp
    end

    def get_interfaces(ipaddr="127.0.0.1", port="80")
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
#      ret = RestClient.post("http://#{ipaddr}:#{port}/restconf/operations/destcloud3:get-interface", { "input" => { } }.to_json, :content_type => :json,
#                            user: @user, password: @password)
        uri = "http://#{ipaddr}:#{port}/restconf/operations/destcloud3:get-interface"
        pp uri
        ret = RestClient.post(uri,
                              { "input" => { } }.to_json,
                              {:content_type => :json,
                               :Authorization => @auth, :Accept => :json})
        return ret.to_s
    end

    def failure_action_port_down(ipaddr = "127.0.0.1", port = "80", iface = "")
        ret = RestClient.post("http://#{ipaddr}:#{port}/restconf/operations/destcloud3:fault-action",
                              { "input" => { "interface" => iface,
                                            "action" => {"port-down" => []}}}.to_json,
                              { :content_type => :json,
                                :Authorization => @auth, :Accept => :json})
        if ret.code != 200 then
            return nil
        end
        result = JSON.parse (ret.to_s)
        uuid = result['output']['uuid']
        return uuid
    end

    def failure_action_all_loss(ipaddr = "127.0.0.1", port="80", iface = "", direction="outbound")
        ret = RestClient.post("http://#{ipaddr}:#{port}/restconf/operations/destcloud3:fault-action",
                              { "input" => { "interface" => iface,
                                            "action" => {"all-lose" => [],
                                                         "direction" => direction}}}.to_json,
                              { :content_type => :json,
                                :Authorization => @auth, :Accept => :json})

        if ret.code != 200 then
            return nil
        end
        result = JSON.parse (ret.to_s)
        uuid = result['output']['uuid']
        return uuid
    end

    def failure_action_packet_loss(ipaddr = "127.0.0.1", port = "80", iface = "", ratio = 0, direction = "outbound")
        ret = RestClient.post("http://#{ipaddr}:#{port}/restconf/operations/destcloud3:fault-action",
                              { "input" => { "interface" => iface,
                                            "action" => {"packet-loss" => ratio,
                                                         "direction" => direction}}}.to_json,
                              { :content_type => :json,
                                :Authorization => @auth, :Accept => :json})
        if ret.code != 200 then
            return nil
        end
        result = JSON.parse (ret.to_s)
        uuid = result['output']['uuid']
        return uuid
    end

    def failure_action_route_change(ipaddr = "127.0.0.1", port = "80", prefix ="", nexthop="")
        ret = RestClient.post("http://#{ipaddr}:#{port}/restconf/operations/destcloud3:fault-action",
                              { "input" => {"action" => {"route-change" =>
                                                         {"prefix" => prefix,
                                                          "nexthop" => nexthop}}}}.to_json,
                              { :content_type => :json,
                                :Authorization => @auth, :Accept => :json})
        if ret.code != 200 then
            return nil
        end
        result = JSON.parse (ret.to_s)
        uuid = result['output']['uuid']
        return uuid
    end

    def failure_action_shaping(ipaddr = "127.0.0.1", port = "80", iface = "", bandwidth = 0, direction="outbound")
        ret = RestClient.post("http://#{ipaddr}:#{port}/restconf/operations/destcloud3:fault-action",
                              { "input" => { "interface" => iface,
                                            "action" => {"shaping" => bandwidth,
                                                         "direction" => direction}}}.to_json,
                              { :content_type => :json,
                                :Authorization => @auth, :Accept => :json})
        if ret.code != 200 then
            return nil
        end
        result = JSON.parse (ret.to_s)
        uuid = result['output']['uuid']
        return uuid
    end

    def failure_action_delay(ipaddr = "127.0.0.1", port = "80", iface = "", delay = 0, direction = "outbound")
        ret = RestClient.post("http://#{ipaddr}:#{port}/restconf/operations/destcloud3:fault-action",
                              { "input" => { "interface" => iface,
                                            "action" => {"delay" => delay,
                                                         "direction" => direction}}}.to_json,
                              { :content_type => :json,
                                :Authorization => @auth, :Accept => :json})
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

    def recover(ipaddr = "127.0.0.1", port = "80", uuid)
        ret = RestClient.post("http://#{ipaddr}:#{port}/restconf/operations/destcloud3:recovery",
                              { "input" => { "uuid" => uuid} }.to_json,
                              { :content_type => :json,
                                :Authorization => @auth, :Accept => :json})
        return ret
    end

    def reload(ipaddr = "127.0.0.1", port = "80")
        ret = RestClient.post("http://#{ipaddr}:#{port}/restconf/operations/destcloud3:reload",
                              { "input" => { }}.to_json,
                              { :content_type => :json,
                                :Authorization => @auth, :Accept => :json})
        return ret
    end

    def set_interface_state(ipaddr = "127.0.0.1", port = "80", iface = "", state = "up")
        ret = RestClient.post("http://#{ipaddr}:#{port}/restconf/operations/destcloud3:set-interface-state",
                              { "input" => { "interface" => iface,
                                            "state" => state} }.to_json,
                              { :content_type => :json,
                                :Authorization => @auth, :Accept => :json})
        return ret
    end
end

