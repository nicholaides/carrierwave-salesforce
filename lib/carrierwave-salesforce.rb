require 'base64'
require 'rubygems'
require 'carrierwave'
require 'rforce'

class CarrierWave::Storage::Salesforce < CarrierWave::Storage::Abstract
  class File
    class DocumentNotFound < Exception
    end
      
    def initialize(uploader, document_id=nil)
      @uploader    = uploader
      @document_id = document_id
    end
    
    def document_id
      @document_id
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
      
      blank_document = CarrierWave::Storage::Salesforce.sobject("Document", nil,
        :Body     => Base64.encode64("waiting for upload..."),
        :Type     => ::File.extname(@uploader.store_path),
        :Name     => ::File.basename(@uploader.store_path),
        :FolderId => @uploader.sf_folder_id
      )
      creation_response = @sf_binding.create(blank_document)

      @document_id = creation_response.createResponse.result[:id]

      upload_params = [CarrierWave::Storage::Salesforce, :perform_upload, @uploader.sf_username, @uploader.sf_password, @document_id, file.path, @sf_binding]
      
      if @uploader.sf_perform_upload
        # if they set perform_upload, then call that
        @uploader.sf_perform_upload[*upload_params]
      else
        # otherwise, perform the upload right now
        klass, *upload_params = upload_params
        klass.send(*upload_params)
      end
    end
    
    private
      def login
        @sf_binding ||= CarrierWave::Storage::Salesforce.login(@uploader.sf_username, @uploader.sf_password)
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
  end
  
  def store!(file)
    File.new(uploader).tap do |sf_file|
      sf_file.store(file)
    end
  end
  
  def retrieve!(document_id)
    CarrierWave::Storage::Salesforce::File.new(uploader, document_id)
  end
  
  def self.sobject(entity_name, id, fields=[])
    sobj = []
    sobj << 'type { :xmlns => "urn:sobject.partner.soap.sforce.com" }' << entity_name
    sobj << 'Id   { :xmlns => "urn:sobject.partner.soap.sforce.com" }' << id if id
    sobj += fields.select{|name,value| value }.to_a.flatten
    [:sObjects, sobj]
  end

  def self.login(user, pass)
    RForce::Binding.new('https://www.salesforce.com/services/Soap/u/19.0', nil).tap do |sf_binding|
      sf_binding.login(user, pass)
    end
  end

  def self.perform_upload(user, pass, document_id, file_path, sf_binding=nil)
    sf_binding ||= login(user, pass)
    sf_binding.update sobject("Document", document_id, :Body => Base64.encode64(IO.read(file_path)))
  end
end

CarrierWave::Uploader::Base.tap do |config|
  config.add_config :sf_username
  config.add_config :sf_password
  config.add_config :sf_folder_id
  config.add_config :sf_perform_upload
end