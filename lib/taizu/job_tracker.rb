module Taizu
  self.init_database
  class JobTracker    
    include DataMapper::Resource
    storage_names[:default] = "gearman_status_updates"
    property :unique_key, String, :length=>64, :key=>true
    property :job_handle, String, :length=>255, :index=>true
    property :function_name, String, :length=>255
    property :data, Text
    property :status, String, :length=>64
    property :message, Text
    property :started, String, :length=>64
    property :finished, String, :length=>64  
    property :duration, String, :length=>64  
    property :last_updated, DateTime, :default=>Time.now
    property :parent_key, String, :length=>64, :index=>true    
    
    def self.init(uniq_id,handle=nil,task_name=nil)
      @args = {:unique_key=>uniq_id, :job_handle=>handle, :function_name=>task_name}      
      jt = self.first_or_new(:unique_key=>uniq_id)
      jt.job_handle = handle
      jt.function_name = task_name
      jt
    end

    def queued(parent=nil,data=nil)
      self.status="QUEUED"
      self.parent_key=parent
      self.data=data
      self.save
    end
    def in_progress
      self.status="IN_PROGRESS"
      self.message=nil
      self.started=DateTime.now.to_s
      self.save
    end
    def completed(msg=nil)
      self.status="COMPLETED"
      self.message=msg
      self.finished=DateTime.now.to_s
      self.duration=duration
      self.save
    end
    
    def failed(msg=nil)
      self.status="FAILED"
      self.message=msg
      self.finished=DateTime.now.to_s
      self.duration=calculate_duration 
      self.save     
    end
    
    private
    def calculate_duration
      (Time.parse(self.started)-Time.parse(self.duration))
    end
  end    

end

