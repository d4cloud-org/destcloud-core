# coding: utf-8

require 'gdbm'
require 'ipaddr'

class TopologyDB
    @db = nil
    def initialize
        @db = {}
    end
    
    def _open_db
#        @db = GDBM.new("/tmp/topology.db",0666,GDBM::SYNC | GDBM::NOLOCK)
    end

    def _close_db
#        @db.close
    end

    def add_uuid(key, value)
        _open_db
        @db[value] = {key => value}
        _close_db
    end
    
    def add_router(node={})
        return if node['ID'] == nil
        _open_db
        @db[node['ID']] = node
        _close_db
    end
    
    def add_line(node={})
        return if node['ID'] == nil

        _open_db
        # search network address
        @db.each_pair do |k,v|
            if v['entity_type'] == 'line' then
                if v['network_address'] == node['network_address'] then
                    @db[k]['nodes'] = @db[k]['nodes'] + node['nodes']
                    _close_db
                    return
                end
            end
        end
        @db[node['ID']] = node
        _close_db
    end
    
    def query(id = nil)
        return nil if id == nil
        _open_db
        return nil if @db[id] == nil
        ret = @db[id]
        _close_db
        return ret
    end

    def query_by_name(name ="")
        _open_db
        # search network address
        @db.each_pair do |k,v|
            if v['entity_name'] == name then
                ret = @db[k]
                _close_db
                return ret
            end
        end
        _close_db
        return nil
    end

    
    def clear_all
        _open_db
        @db.clear
        _close_db
    end

    def dump_all
        _open_db
        ret = @db.values
        _close_db
        return ret
    end
end


class TopologyManager

    def initialize
	@built = false
        @db = TopologyDB.new
        @subdb = TopologyDB.new
        @t = nil
    end

    def query_entity(entity)
        # query router configuration of the entity from DC3
        # esample of entity
        # {
        #  "entity_name": "Osaka Juniper",
        #  "IP_Address": "192.168.0.1",
        #  "port_number": "22",
        #  "network_od": "junos",
        #  "username": "admin",
        #  "password": "hogehoge"
        #  }
    end

    def query_interfaces(entity)
        # get interfaces via RESTCONF
        ret = $dc3.get_interfaces(entity['IP_address'].to_s.gsub(/\s+/,""),
                                  entity['port_number'].to_s.gsub(/\s+/,""))
        return ret
    end

    def add_to_topology(e, interfaces)
        # add router
      # decide uuid of the router
        uuid = UUIDTools::UUID.random_create.to_s
        router_uuid = uuid
        node = {}
        node['entity_type'] = "router"
        node['entity_name'] = e['entity_name']
        node['ID'] = uuid
        node['port_number'] = e['port_number'].to_s.gsub(/\s+/,"")
        node['IP_address'] = e['IP_address'].to_s.gsub(/\s+/, "")
        node['protocol'] = e['protocol']
        node['network_os'] = e['network_os']
        node['username'] = e['username']
        node['password'] = e['password']
       
        ifnames=[]
        # assign portnumber for each interfaces.
        interfaces['output']['interface'].each do |i|
          pp i
            if i['admin-status'] == false then
                next
            end
            ifnames << i['name']
        end
        node['IF_numbers'] = ifnames.length
        node['ifnames'] = ifnames
        node['interfaces'] = interfaces['output']['interface']

        
        @db.add_router(node)
        
        # add line for all interfaces

        interfaces['output']['interface'].each do |i|
            # i includes
            # name
            # description
            # mac-address
            # physical
            # ipv4-addresses (addr/prefix)
            # ipv6-addresses (addr/prefix)
            # admin-status
            # oper-status
            # vlan-id
            # parent-device

            if i['admin-status'] == false then
                next
            end

            if i['ipv4-addresses'].nil? or i['ipv4-addresses'].length == 0 then
                next
            end
            
            if i['ipv4-addresses'][0].to_s =~ /^127\./ then
                next
            end
        
            # decide uuid of the line
            uuid = UUIDTools::UUID.random_create.to_s

            # construct node
            node = {}
            node['entity_type'] = 'line'
            node['ID'] = uuid
            node['nodes'] = [
                             {
                              "routerID" => router_uuid,
                              "router_IF_number" => ifnames.index(i['name']),
                              "router_IF_name" => i['name']
                             }
                            ]
            node['network_address'] = IPAddr.new(i['ipv4-addresses'][0]).to_s
            @db.add_line(node)
        end
    end
    
    def add_to_subtopology(uuid, e)
        if e['entity_type'] == "router" then
            @subdb.add_router(e)
        else
            @subdb.add_line(e)
            # link up all interfaces on this line
            e['nodes'].each do |router|
                router_uuid = router['routerID']
                router_ifname = router['router_IF_name']
                
                router_entity = $topo.get_entity(router_uuid)
                $dc3.set_interface_state(router_entity['IP_address'],
                                         router_entity['port_number'],
                                         router_ifname,
                                         "up")
            end

        end
    end

    def build_topology(data)
        #if not @t.nil? then
        #@t.exit
#            @t = nil

        #        end
        @built = false
        @db = TopologyDB.new
        uuid = UUIDTools::UUID.random_create.to_s
        @db.add_uuid('entire_topology_ID', uuid)

        EM::defer do #@t = Thread.new do 
            #Thread.pass
            data.each do |entity|
                i = query_interfaces (entity)
                add_to_topology(entity, JSON.load(i))
            end
            
            # reload all router
            topo = get_entire_topology()
            topo.each do |e|
                if e['entity_type'] == "router" then
                    $dc3.reload(e['IP_address'], e['port_number'])
                end
            end

            @built = true
            #Thread.stop
            def stop
            end
        end
    end
    
    def build_sub_topology(data)
        entire_topology_id = data[0]['entire_topology_ID']
        sub_topology_id = UUIDTools::UUID.random_create.to_s
        ids = data[1]['IDs']
	ids.each do |h|
            e = get_entity(h['ID'])
            add_to_subtopology(sub_topology_id, e)
	end
        return sub_topology_id
    end

    def set_entire_entities(yaml_str)
	@built = false
        @db.clear_all
        @subdb.clear_all
        pp "YAML----->>"
        pp yaml_str
        pp "YAML<<====="
	data = YAML.load(yaml_str)
	build_topology(data)
    end

    def set_sub_entities(yaml_str)
        @subdb.clear_all
        pp "YAML----->>"
        pp yaml_str
        pp "YAML<<====="
	data = YAML.load(yaml_str)
	uuid = build_sub_topology(data)
        return uuid
    end

    def get_entire_topology
        return @db.dump_all
    end
    def rebuild_entire_topology(topo)
      ret = []
      topo.each do |entity|
          if ! entity['entire_topology_ID'].nil? then
              ret << entity
          elsif entity['entity_type'] == "router" then
              e={}
              # router
              e['entity_type'] = "router"
              e['entity_name'] = entity['entity_name']
              e['ID'] = entity['ID']
              e['IF_numbers'] = entity['IF_numbers']
              ret << e
          else
              # line
              e={}
              if entity['nodes'].length != 2 then
                  next
              end
              e['entity_type'] = "line"
              e['ID'] = entity['ID']
              e['nodes'] = []
              entity['nodes'].each do |n|
              e['nodes'] << 
              {
               "routerID" => n['routerID'],
               "router_IF_number" => n['router_IF_number']
              }
              end
              ret << e
          end
      end
      return ret
    end
    
    def get_sub_topology(uuid)
        return @subdb.dump_all
    end

    def get_build_status
	return @built
    end

    def get_entity(uuid)
        return @db.query(uuid)
    end

    def get_entity_by_name(name)
        return @db.query_by_name(name)
    end

    def clear_entire_topology
        @db.clear_all
        @build = false
        @t.stop
    end
end

