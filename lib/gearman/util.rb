# Gearman, by default, isn't Ruby 1.9 compatible.  These are some fixes to 
# make it unicode aware
module Gearman
  class Util
    def Util.send_request(sock, req)
      len = with_safe_socket_op{ sock.write(req) }
      if len != req.bytesize
        raise NetworkError, "Wrote #{len} instead of #{req.size}"

       end
    end
    def Util.pack_request(type_name, arg='')
      type_num = NUMS[type_name.to_sym]
      raise InvalidArgsError, "Invalid type name '#{type_name}'" unless type_num
      arg = '' if not arg
        if "".respond_to?(:force_encoding)
          "\0REQ" + [type_num, arg.size].pack('NN').force_encoding("UTF-8") + arg
        else
          "\0REQ" + [type_num, arg.size].pack('NN') + arg
        end
    end    
  end
end