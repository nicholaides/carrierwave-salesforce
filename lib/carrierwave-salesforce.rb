require 'base64'
require 'rubygems'
require 'carrierwave'
require 'rforce'

class CarrierWave::Storage::Salesforce < CarrierWave::Storage::Abstract
  class File
    class DocumentNotFound < Exception; end
      
    def initialize(uploader, document_id=nil)
      @uploader    = uploader
      @document_id = document_id
    end
    
    def document_id
      @document_id
    end
    
    def identifier
      document_id
    end
    
    def file_name
      download  if @file_name.nil?
      @file_name
    end
    
    def folder_id
      @uploader.sf_folder_id
    end
    
    def read
      download  if @body.nil?
      @body
    end
    
    def delete
      login
      
      @sf_binding.delete([:id, document_id]).deleteResponse.result.success == "true"
    end
    
    def store(file)
      login
      
      blank_document = sobject("Document", nil,
        :Body     => Base64.encode64(IO.read(file.path)),
        :Type     => ::File.extname(@uploader.store_path),
        :Name     => ::File.basename(@uploader.store_path),
        :FolderId => @uploader.sf_folder_id
      )
      creation_response = @sf_binding.create(blank_document)

      @document_id = creation_response.createResponse.result[:id]
    end
    
    private
      def login
        @sf_binding ||= RForce::Binding.new('https://www.salesforce.com/services/Soap/u/19.0', nil).tap do |sf_binding|
          sf_binding.login(@uploader.sf_username, @uploader.sf_password)
        end
      end
    
      def download
        login
        
        retrieve_response = @sf_binding.retrieve([
          :fieldList, "Body, Name",
          'type { :xmlns => "urn:sobject.partner.soap.sforce.com" }', "Document",
          :ids, document_id
        ])
        
        result     = retrieve_response.retrieveResponse.result  or raise DocumentNotFound
        @body      = Base64.decode64(result.Body)
        @file_name = result.Name
      end
      
      def sobject(entity_name, id, fields=[])
        sobj = []
        sobj << 'type { :xmlns => "urn:sobject.partner.soap.sforce.com" }' << entity_name
        sobj << 'Id   { :xmlns => "urn:sobject.partner.soap.sforce.com" }' << id if id
        sobj += fields.select{|name,value| value }.to_a.flatten
        [:sObjects, sobj]
      end
  end
  
  def store!(file)
    File.new(uploader).tap do |sf_file|
      sf_file.store(file)
    end
  end
  
  def retrieve!(document_id)
    File.new(uploader, document_id)
  end
end

CarrierWave.configure do |config|
  config.storage_engines[:salesforce] = "CarrierWave::Storage::Salesforce"
end

CarrierWave::Uploader::Base.tap do |base|
  base.add_config :sf_username
  base.add_config :sf_password
  base.add_config :sf_folder_id
end