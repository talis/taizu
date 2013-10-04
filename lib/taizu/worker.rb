module Taizu
  module Worker
    attr_reader :gearman_worker
    
    def self.included(other)
      other.extend(ClassMethods)
    end
    
    def gearman_worker
      @gearman_worker = Gearman::Worker.new(@servers||"localhost:4730") unless @gearman_worker
      @gearman_worker
    end
    
    def update_message(job, msg)
      jt = JobTracker.first(:unique_key=>job.uniq)
      jt.message = msg
      jt.save
    end
    
    def _kill(data, job)
      case self.respond_to?(:kill)
      when true then self.kill(data,job)
      else
        jt = JobTracker.init(job.uniq, job.handle)
        jt.completed("Done")
        puts data
        exit!
      end
    end
    
    def _list_abilities(data, job)
      abilities = []
      self.class.get_abilities.each do |a|
        abilities << case a
        when Hash then "#{self.class.namespace}_#{self.class.number}_#{a.keys.first}"
        else
          "#{self.class.namespace}_#{self.class.number}_#{a}"
        end
      end
      abilities
    end        
    
    def work
      self.class.get_abilities.each do |task|
        if task.is_a?(Hash)    
          task_name = nil
          method_name = nil        
          task.each_pair do |key, val|
            task_name = key
            method_name = val
          end
        else
          task_name = task
          method_name = task
        end
        gearman_worker.add_ability("#{self.class.namespace}_#{self.class.number}_#{task_name}") do |data,job|
          jt = JobTracker.init(job.uniq, job.handle, "#{self.class.namespace}_#{self.class.number}_#{task_name}")
          jt.in_progress
          (response, tracker_log) = self.send(method_name, data, job)
          jt.completed case
          when tracker_log then tracker_log
          else
            response
          end
          response
        end  
      end    
 
      loop { gearman_worker.work }
    end
    
    module ClassMethods
      attr_reader :namespace, :version
      def namespace        
        @namespace||self.name
      end
      
      def number
        @number||1
      end
      
      def job_prefix(namespace, number)
        @namespace = namespace
        @number = number
      end
      
      def abilities(*tasks)
        @abilities=tasks
        unless kill_defined?
          @abilities << {:kill => :"_kill"}
        end
        unless list_functions_defined?
          @abilities << {:"listFunctions" => :"_list_abilities"}
        end
      end
      
      def kill_defined?
        @abilities.each do |a|
          if (a.is_a?(Hash) && a.keys.first.to_s == "kill") || a.to_s == "kill"
            return true
          end
        end
        false
      end            
      
      def list_functions_defined?
        @abilities.each do |a|
          if (a.is_a?(Hash) && a.keys.first.to_s == "listFunctions") || a.to_s == "listFunctions"
            return true
          end
        end
        false
      end      
      def get_abilities
        @abilities||[{:kill => :"_kill"}, {:"listFunctions" => :"_list_abilities"}]
      end
    end
  end
end