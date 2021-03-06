require 'net/http'
require 'uri'
require 'linguara/configuration'
require 'linguara/utils'

module Linguara
  extend Linguara::Utils
  autoload :ActiveRecord, 'linguara/active_record'
  
  class << self
    attr_accessor :configuration
    
    def configure
      self.configuration ||= Configuration.new
      yield(configuration)
    end
    
    # Use this method in your controller to accepr and save incoming translations
    def accept_translation(translation)
      target_language = translation[:target_language]
      translation[:paragraphs].each do |key,value|
        class_name,id,order,field_name = key.split('_')
        original_locale = I18n.locale
        element = class_name.constantize.find(id)
        
        I18n.locale = target_language
        element.send("#{field_name}=", value.gsub(/<p>(.*?)<\/p>/, "\\1\n") )
        element.save(false)
        I18n.locale = original_locale
      end
    end
    
    def send_translation_request(element, target_language, due_date = nil )
      due_date ||= Date.today + Linguara.configuration.request_valid_for.to_i.days unless Linguara.configuration.request_valid_for.blank?
      due_date ||= Date.today + 1.month
      log("due date: #{due_date}")
      url= URI.parse(Linguara.configuration.server_path + 'api/create_translation_request.xml')
      translation_hash = { :translation => {
          :return_url => Linguara.configuration.return_url,
          :due_date => due_date.to_s,
          :source_language => I18n.locale.to_s,
          :target_language => target_language,
          :paragraphs  => element.fields_to_send
          }}
      req = prepare_request(url, translation_hash)
      #TODO handle timeout
      log("SENDING TRANSLATION REQUEST TO #{url.path}: \n#{req.body}")
      begin
        res = Net::HTTP.new(url.host, url.port).start {|http| http.request(req) }
        log("LINGUARA RESPONSE: #{res.message} -- #{res.body}")
        return res
      rescue Errno::ETIMEDOUT 
        handle_request_error
      end
    end

    def send_status_query(translation_request_id)
      url= URI.parse("#{Linguara.configuration.server_path}api/#{translation_request_id}/translation_status.xml")
      req = prepare_request(url, {})
      logger.debug("SENDING STATUS QUERY REQUEST TO #{url.path}: \n#{req.body}")
      begin
        res = Net::HTTP.new(url.host, url.port).start {|http| http.request(req) }
        logger.debug("LINGUARA RESPONSE: #{res.message} -- #{res.body}")
        return res
      rescue Errno::ETIMEDOUT
        handle_request_error
      end
    end
    
    # Override this method if you want to perform some action when connection
    # with linguara cannot be established e.g. log request or redo the send
    def handle_request_error
      log("ERROR WHILE SENDING REQUEST TO LINGUARA: #{$!}")
    end
    
    # Log a linguara-specific line. Uses Rails.logger
    # by default. Set Lingurara.config.log = false to turn off.
    def log message
      logger.info("[linguara] #{message}") if logging?
    end

    def logger #:nodoc:
      Rails.logger
    end

    def logging? #:nodoc:
      Linguara.configuration.log
    end
    
    private
    def prepare_request(url, data)
      req = Net::HTTP::Post.new(url.path)
      req.body = serialize_form_data({
        :site_url => Linguara.configuration.site_url,
        :account_token => Linguara.configuration.api_key
        }.merge(data))
      req.content_type = 'application/x-www-form-urlencoded'
      req.basic_auth(Linguara.configuration.user, Linguara.configuration.password)
      req
    end
  end
end

ActiveRecord::Base.send(:include, Linguara::ActiveRecord)