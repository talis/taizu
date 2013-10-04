# Support for http digest auth
# Discovered here: http://johan.bingodisk.com/public/code/net_digest_auth.rb

require 'digest/md5'
require 'net/http'
require 'net/http/digest_auth'

module DataMapperRest
  class Connection  
     
    def run_verb(verb, data = nil)
      request do |http|
        klass = DataMapper::Ext::Module.find_const(Net::HTTP, DataMapper::Inflector.camelize(verb))
        userinfo = nil
        @uri.normalize!
        if @uri.user && @uri.password
          userinfo = [@uri.user,@uri.password]
          @uri.userinfo=nil
          request = klass.new(@uri.to_s, @format.header)
          result = http.request(request, data)
        end        
        request = klass.new(@uri.to_s, @format.header)
        if userinfo        
          digest_auth = Net::HTTP::DigestAuth.new
          @uri.user,@uri.password = userinfo
          auth = digest_auth.auth_header @uri, result['www-authenticate'], request.method  
          request.add_field 'Authorization', auth
        end
        result = http.request(request, data)
        handle_response(result)
      end
    end
  end    
  class Adapter < DataMapper::Adapters::AbstractAdapter
    def read(query)
      model = query.model
      records = if id = extract_id_from_query(query)
        begin
          response = connection.http_get("#{resource_name(model)}/#{id}")
          [ parse_resource(response.body, model) ]
        rescue DataMapperRest::ResourceNotFound
          return []
        end
      else
        query_string = if (params = extract_params_from_query(query)).any?
          params.map { |k,v| "#{CGI.escape(k.to_s)}=#{CGI.escape(v.to_s)}" }.join('&')
        end
        begin           
          response = connection.http_get("#{resource_name(model)}#{'?' << query_string if query_string}")
          parse_resources(response.body, model)
        rescue DataMapperRest::ResourceNotFound
          return []
        end          
      end
      query.filter_records(records)
    end
  end
end