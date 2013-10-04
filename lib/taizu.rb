module Taizu
  require 'rubygems'  
  require 'gearman'
  require 'uuid'
  require 'dm-core'
  require 'dm-migrations'
  # First pull in changes to gearman-ruby
  require File.dirname(__FILE__) + '/gearman/util'
  require File.dirname(__FILE__) + '/gearman/worker'
  
  if ENV['TAIZU_GEARMAN']
    @gearman_servers = []
    ENV['TAIZU_GEARMAN'].split(",").each do |s|
      @gearman_servers << s.strip
    end
  end
  if ENV['TAIZU_DB']
    @database=ENV['TAIZU_DB']
  end
    
  def self.configure(config)
    if config["gearman"]["servers"]
      @gearman_servers = config["gearman"]["servers"]
    end
    if config["database"]
      @database = config["database"]
    end
  end
  
  def self.gearman_servers
    @gearman_servers
  end
  
  def self.database=(conn_string)
    @database = conn_string
    init_database
  end 
  
  
  def self.database
    @database || {:adapter=>:in_memory}
  end
   
  def self.init_database
    DataMapper.setup(:default, Taizu.database)  
    if (Taizu.database.is_a?(String) && Taizu.database =~ /^rest:/) || (Taizu.database.is_a?(Hash) && Taizu.database["adapter"] == "rest")
      require File.dirname(__FILE__) + '/dm/rest'
    end      
  end
  require File.dirname(__FILE__) + '/taizu/client'  
  require File.dirname(__FILE__) + '/taizu/worker'    
  require File.dirname(__FILE__) + '/taizu/job_tracker'

end