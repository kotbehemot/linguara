module Linguara
  module Utils
     #TODO describe it, spec and move somewhere else
     # http://www.keyongtech.com/5211204-nested-http-params-on-ruby
     def serialize_form_data(data, path = "",serialized_params = [])
        if data.kind_of? Hash
          data.each_pair{|k,v| token = (path == "" ? CGI::escape(k.to_s) :  "[#{CGI::escape(k.to_s)}]"); serialize_form_data(v, "#{path}#{token}",serialized_params)}
        elsif data.kind_of? Array
          data.each{|v| serialize_form_data(v, "#{path}[]", serialized_params) }
        else
          #end of recursion
          serialized_params << "#{path}=#{CGI::escape(data.to_s)}"
        end

        return serialized_params.join("&") if (path == "")
      end
  end
end