require 'rubygems'
require File.dirname(__FILE__) + '/../taizu'
require 'sinatra/base'
require 'rack/conneg'
require 'crack'
require 'dm-serializer'



class Server < Sinatra::Base
  include Taizu
  use(Rack::Conneg) { |conneg|
    conneg.set :accept_all_extensions, false
    conneg.set :fallback, :xml
    conneg.ignore('/workers')
    conneg.provide([:xml, :json])
  }  
  configure do
    DataMapper.auto_upgrade!
  end
  before do  
    content_type negotiated_type
  end
    
  get "/gearman_status_updates" do
    respond_to do |wants|
      wants.xml {
        JobTracker.all.to_xml.gsub("taizu-job_tracker", "gearman_status_update")
      }
      wants.json {
        JobTracker.all.to_json.gsub("taizu-job_tracker", "gearman_status_update")
      }  
    end  
  end
  get "/gearman_status_updates/:id" do

    if resource = JobTracker.get(params[:id])
      respond_to do |wants|
        wants.xml {
          resource.to_xml.gsub("taizu-job_tracker", "gearman_status_update")
        }
        wants.json {
          resource.to_json.gsub("taizu-job_tracker", "gearman_status_update")
        }
      end
    else
      not_found
    end  
  end

  post '/gearman_status_updates' do
    vals = Crack::XML.parse(request.body.read)
    respond_to do |wants|
      wants.xml {
        JobTracker.create(vals["taizu_job_tracker"]).to_xml.gsub("taizu-job_tracker", "gearman_status_update")
      }
      wants.json {
        JobTracker.create(vals["taizu_job_tracker"]).to_json.gsub("taizu-job_tracker", "gearman_status_update")
      }
    end
  end

  delete '/gearman_status_updates/:id' do
    JobTracker.get(params[:id]).destroy
  end

  put '/gearman_status_updates/:id' do
    resource = JobTracker.get(params[:id])
    vals = Crack::XML.parse(request.body.read)
    resource.update(vals['taizu_job_tracker'])  
  end
  
  get '/workers/*' do
    content_type "text/plain"
    out = ""
    CONFIG["workers"].each do |worker, data|
      unless params[:splat] == [""]
        next unless [worker] == params[:splat]
      end
      out << worker + "\n"
      out << "\tdescription: #{data['description']}\n" if data['description']
      out << "\tcommand:  #{data['command']}\n"
      out << "Processes:\n"
      ps = IO.popen("ps -ef | grep \"#{data["command"]}\"")
      processes = ps.read
      processes.split(/\n/).each do |process|
        next if process =~ /\sgrep\s/
        out << process + "\n"
      end
    end
    out
  end
  
  put '/workers/:id' do
    content_type "text/plain"
    worker = CONFIG["workers"][params[:id]]
    not_found unless worker
    num_workers = request.body.read.to_i
    num_workers.times do |work|
      puts worker["command"]
      exec("#{worker["command"]}") if fork == nil
    end
    "#{num_workers} workers launched."
  end  

  run! if app_file == $0
end

