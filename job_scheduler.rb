# Coding: utf-8

require 'gdbm'

class JobQueue
    @queue = nil
    def initialize
        @queue = {}
    end

    def _open_db
#        @queue = GDBM.new("/tmp/jobqueue.db",0666,GDBM::SYNC | GDBM::NOLOCK)
    end

    def _close_db
#        @queue.close
    end
    
    def push_event(event,jobuuid,time)
        # event data is the below:
        # {
        #   fault_type: port down
        #   fault_ID: uuid of event in the scenario
        #   time: relative from "start_time"
        #   1.
        #   fault_place:
        #       { routerID: uuid of router
        #        interface_number: }
        #   2. fault_place: uuid of line
        #      loss_ratio: (0.0 , 100]
        #   3. fault_place: uuid of line
        #      bandwidth: (kbps)
        #   4. recover_ID:
        # }
        event['time'] = time.to_s
        event['job_id'] = jobuuid
        _open_db
        if @queue[time.to_s].nil? then
            @queue[time.to_s] = [event]
        else
            @queue[time.to_s] << event
        end
        _close_db
    end

    def first
        _open_db
        t = @queue.keys.sort.first
        e = @queue[t]
        @queue.delete(t)
        _close_db
        return e
    end

    def get
        _open_db
        t = @queue.keys.sort.first
        ret = @queue[t]
        _close_db
        return ret
    end

    def search_job(jobuuid)
        _open_db
        @queue.each_value do |e|
            if e['job_id'] == jobuuid then
                _close_db
                return e
            end
        end
        _close_db
        return nil
    end

    def empty?
        if @queue.length == 0
            return true
        else
            return false
        end
    end
end

class EventProcesser
    def initialize
        @event_history=[]
    end

    def do_port_down(e)
        pp "do port down"
        router_uuid = e['fault_place']['router_ID']
        $logger.log(router_uuid, "ROUTER", "do port down")
        router_name = e['fault_place']['router_name']
        ifindex = e['fault_place']['interface_number'].to_i
        router = $topo.get_entity(router_uuid)
        if router.nil? and !router_name.nil? then
            router = $topo.get_entity_by_name(router_name)
        end
        return if router.nil?

        dc3_uuid = $dc3.failure_action_port_down(router['IP_address'],
                                                 router['port_number'],
                                                 router['ifnames'][ifindex])
        $logger.log(dc3_uuid, "DC3ID", "done port down")
        @event_history << [e['fault_uuid'], dc3_uuid, router['IP_address'], router['port_number']]
    end

    def do_packet_loss(e)
        pp "do packet loss"
        line_uuid = e['fault_place']
        $logger.log(line_uuid, "LINE", "do packet loss")

        line = $topo.get_entity(line_uuid)

        line['nodes'].each do |router|
            router_uuid = router['routerID']
            router_ifname = router['router_IF_name']

            router_entity = $topo.get_entity(router_uuid)
            if e['loss_ratio'].to_i == 100 then
                dc3_uuid = $dc3.failure_action_all_loss(router_entity['IP_address'],
                                                           router_entity['port_number'],
                                                           router_ifname)
            else
                dc3_uuid = $dc3.failure_action_packet_loss(router_entity['IP_address'],
                                                           router_entity['port_number'],
                                                           router_ifname,
                                                           e['loss_ratio'].to_i)
            end
            $logger.log(dc3_uuid, "DC3ID", "done packet loss")
            @event_history << [e['fault_uuid'] , dc3_uuid, router['IP_address'],router['port_number']]
        end
    end

    def do_traffic_shaping(e)
        pp "do traffic shaping"
        line_uuid = e['fault_place']
        $logger.log(line_uuid, "LINE", "do traffic shaping")

        line = $topo.get_entity(line_uuid)

        line['nodes'].each do |router|
            router_uuid = router['routerID']
            router_ifname = router['router_IF_name']

            router_entity = $topo.get_entity(router_uuid)
            dc3_uuid = $dc3.failure_action_shaping(router_entity['IP_address'],
                                                   router_entity['port_number'],
                                                   router_ifname,
                                                   e['bandwidth'].to_i * 1024)
            $logger.log(dc3_uuid, "DC3ID", "done traffic shaping")
            @event_history << [e['fault_uuid'] , dc3_uuid, router['IP_address'],router['port_number']]
        end
    end

    def do_delay(e)
        pp "do delay"
        line_uuid = e['fault_place']
        $logger.log(line_uuid, "LINE", "do delay")

        line = $topo.get_entity(line_uuid)

        line['nodes'].each do |router|
            router_uuid = router['routerID']
            router_ifname = router['router_IF_name']

            router_entity = $topo.get_entity(router_uuid)
            dc3_uuid = $dc3.failure_action_delay(router_entity['IP_address'],
                                                 router_entity['port_number'],
                                                 router_ifname,
                                                 e['delay'].to_i)
            $logger.log(dc3_uuid, "DC3ID", "done delay")
            @event_history << [e['fault_uuid'] , dc3_uuid, router['IP_address'],router['port_number']]
        end
    end

    def do_recover(e)
        pp "do recover"
        $logger.log(e['recover_ID'], "EVENT", "do recover")
        # search dc3 uuid from fault uuid
        @event_history.each do | arr |
            if arr[0] == e['recover_ID'] then
                # call dc3 by dc3uuid
                dc3_uuid = $dc3.recover(arr[2],arr[3],arr[1])
                $logger.log(dc3_uuid, "DC3ID", "done recover")
            end
        end
    end

    def exec_event(e)
        if e['sub_topology_ID'] != nil then
            $logger.log(e['sub_topology_ID'], "TOPOLOGY",
                        "Starting on sub-topology")
            return
        end
        if e['end_time'] != nil then
            return
        end
        
        case e['fault_type']
        when 'port down' then
            do_port_down(e)
        when 'packet loss' then
            do_packet_loss(e)
        when 'traffic shaping' then
            do_traffic_shaping(e)
        when 'delay' then
            do_delay(e)
        when 'recover' then
            do_recover(e)
        end
    end
end

class EventRunner
    @runthread = nil
    @jq = nil
    @ep =nil
    
    def initialize
        @runthread = nil
        @jq = nil
        @ep = EventProcesser.new
    end

    def run_thread(jq)
        # loop
        # check top of queue, if it is the time to exec
        # if it's the time, EventProcesser.exec_event(e)
        # if it's still not the time, calc. interval to next and sleep
        while true
            while true
                if jq.empty? then
                    pp "scenario finished"
                    sleep 1
                    return
                end
                
                elist = jq.get
                t = Time.now.to_f
                if elist[0]['time'].to_f <= t then
                    elist = jq.first
                    elist.each do |e|
                        @ep.exec_event(e)
                    end
                else
                    break
                end
            end
            interval = elist[0]['time'].to_f - t
            pp "waiting #{interval} (sec)"
            sleep(interval)
        end
    end
    
    def start(jobqueue)
        if ! @runthread.nil? then
            @runthread.exit
        end
        @jq = jobqueue
        EM::defer do
            run_thread(@jq)
        end
        # @runthread = Thread.new { run_thread(jq) }
    end

    def stop
        return if @runthread.nil? 
        @runtread.exit
    end

    def wakeup
        return if @runthread.nil?
        
        if @runthread.stop? then
            @runthread.wakeup
        end
    end
end

class JobScheduler
    def initialize
	@jq = JobQueue.new
        @runner = EventRunner.new
    end

    def push_scenario_to_jobqueue(data={}, jobuuid="", start_time=nil)
        if start_time == nil then
            # if start_time is not specified, use 10sec after from now
            start_time = Time.now + 5
        end
        start_time = start_time.to_f # Time to fp number
	data.each do |event|
            if event['time'].nil? or event['time'] == 0 then
                time = start_time + 1
            else
                time = start_time + (event['time'].to_f / 1000) + 1
            end
            @jq.push_event(event,jobuuid, time)
	end
    end
    
    def register_scenario(yaml_str, start_time=nil)
        # assign jobuuid
	jobuuid = UUIDTools::UUID.random_create.to_s
        pp "YAML>>"
        pp yaml_str
        pp "<<YAML"
	data = YAML.load(yaml_str)
        if start_time == nil then
          start_time = Time.now + 5
        end
        timestr = start_time.to_s
        pp "Register scenario (JOB: #{jobuuid}) start from #{timestr}"
        $logger.log(jobuuid, "JOB", "register scenario start from #{timestr}")
	push_scenario_to_jobqueue(data, jobuuid, start_time)
#        @runner.wakeup
	return jobuuid
    end

    def get_job_status(uuid)
        result = @jq.search_job(uuid)
        if result.nil? then
            # empty in job queue
            return false
        else
            # exists in job queue
            return true
        end
    end

    def run
        @runner.start(@jq)
    end
end

