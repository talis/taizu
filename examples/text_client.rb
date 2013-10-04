require File.dirname(__FILE__) + '/../lib/taizu'
class TextClient
  include Taizu::Client
  
  # Examples of how to call simple tasks (that is, no fancy schmancy pre/post processing)
  task :textexample_1_reverse
  # Usually the method name is the third (through last) token of the "_"-delimited function name, but you can also set an alias
  # (Useful if, for example, you are calling two tasks that would result in the same method name)
  task :textexample_1_capitalize, :alias=>:upcase
  # You can also pass options
  task :textexample_1_space_out, :on_complete=>Proc.new{ |response| puts "Spaced out -> #{response}" }
  
  # You can also create more sophisticated jobs.  Every method needs two arguments: the job's data and an (optional)
  # parent job's unique key
  def downcase(data, parent_uniq=nil)
    task = init_task('textexample_1_lowercase', data, {}, parent_uniq) 
    task.on_complete {|t| puts "Original downcase: #{t}\nNow let's reverse it.";reverse(t, task.uniq)}
    ts = Gearman::TaskSet.new(gearman_client)
    ts.add_task(task)
  end
end

tc = TextClient.new
tc.reverse("Hello World!")
tc.upcase("a line of text.")
tc.space_out("Totally Groovy")
tc.downcase("The Unbearable Lightness of Being")