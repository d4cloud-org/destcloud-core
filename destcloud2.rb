#!/usr/bin/env ruby
# coding: utf-8

require 'eventmachine'
require 'thin'
require 'sinatra'
#require 'sinatra/reloader'
require 'yaml'

require 'syslog/logger'
require 'uuidtools'
require 'pp'

require 'dclogger'
require 'dc3lib'
#require './dc3lib_stub'
require 'topology_manager'
require 'job_scheduler'


$topo = TopologyManager.new
$jobsche = JobScheduler.new
$logger = DCLogger.new
$dc3 = DC3Lib.new

$logger.log(nil,nil, "Starting DESTCloud2")

set :bind, '0.0.0.0'

get '/entities' do
    content_type :yaml
    # return status of topology manager
    ret = $topo.get_build_status
    if ret then
        word = "topology available"
    else
        word = "processing"
    end
    [200, YAML.dump({"status" => word})]
end

post '/entities' do
    content_type :yaml
    # receive entities YAML
    request.body.rewind
    data = request.body.read
    ret = $topo.set_entire_entities(data)

    [200, ""]
end

get '/topology' do
    content_type :yaml
    # provide topology YAML
    data = $topo.get_entire_topology
    realdata = $topo.rebuild_entire_topology(data)
    [200, YAML.dump(realdata)]
end

post '/sub_topology' do
    content_type :yaml
    # receive scenario YAML
    request.body.rewind
    data = request.body.read
    uuid = $topo.set_sub_entities(data)
    [200, YAML.dump({"sub_topology_ID" => uuid})]
end

get '/sub_topology/:uuid' do |uuid|
    content_type :yaml
    # provide topology YAML
    data = $topo.get_sub_topology(uuid)
    realdata = $topo.rebuild_entire_topology(data)
    [200, YAML.dump(realdata)]
end

get '/sub_topology' do
    content_type :yaml
    # provide topology YAML
    data = $topo.get_sub_topology("")
    realdata = $topo.rebuild_entire_topology(data)
    [200, YAML.dump(realdata)]
end

post '/scenario/:start' do |start|
    content_type :yaml
    # receive scenario YAML
    request.body.rewind
    data = request.body.read
    if start =~ /^\+(\d+)/ then
        start_time = Time.now + $1.to_i
    else
        start_time = Time.at(start.to_i)
    end
    if start_time < Time.now then
        [404, "Start time is not found (past from now)."]
    else
        uuid = $jobsche.register_scenario(data, start_time)
        $jobsche.run
        [200, YAML.dump({"job_id" => uuid})]
    end
end

post '/scenario' do
    content_type :yaml
    # receive scenario YAML
    request.body.rewind
    data = request.body.read
    start_time = Time.now + 5 # tentative assign
    uuid = $jobsche.register_scenario(data, start_time)
    $jobsche.run
    [200, YAML.dump({"job_id" => uuid})]
end

get '/job/*' do |jobid|
    content_type :yaml
    # return job status
    ret = $jobsche.get_job_status(jobid)    
    [200, YAML.dump({"status" => ret.to_s})]
end

post '/reload' do
    content_type :yaml
    request.body.rewind
    data = request.body.read
    req = YAML.load(data)
    
    if req['exec'] == true or req['exec'] == "true" then
        topo = $topo.get_entire_topology()
        topo.each do |e|
            if e['entity_type'] == "router" then
                $dc3.reload(e['IP_address'],
                            e['port_number'])
            end
        end
    end
    [200, ""]
end

get '/' do
    content_type :html
  'This is DESTCloud 2 Server.'
end

