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
      @uploader.folder_id
    end
    
    def read
      download  if @body.nil?
      @body
    end
    
    def delete
      CarrierWave::Storage::Salesforce.delete(@uploader, document_id)
    end
    
    def store(file)
      @document_id = CarrierWave::Storage::Salesforce.upload(file, @uploader)
    end
    
    private
      def download
        @body, @file_name = CarrierWave::Storage::Salesforce.download(@document_id, @uploader)
      end
  end
  
  def store!(file)
    sf_file = CarrierWave::Storage::Salesforce::File.new(uploader)
    sf_file.store(file)
    sf_file
  end
  
  def self.sobject(entity_name, id, fields=[])
    sobj = []
    sobj << 'type { :xmlns => "urn:sobject.partner.soap.sforce.com" }' << entity_name
    sobj << 'Id   { :xmlns => "urn:sobject.partner.soap.sforce.com" }' << id if id
    sobj += fields.select{|name,value| value }.to_a.flatten
    [ :sObjects, sobj ]
  end

  def self.login(user, pass)
    sf_binding = RForce::Binding.new('https://www.salesforce.com/services/Soap/u/19.0', nil)
    sf_binding.login(user, pass)
    sf_binding
  end

  def self.download(document_id, uploader)
    sf_binding = login(uploader.username, uploader.password)
    retrieve_response = sf_binding.retrieve([
      :fieldList, "Body, Name",
      'type { :xmlns => "urn:sobject.partner.soap.sforce.com" }', "Document",
      :ids, document_id
    ])
    if retrieve_response[:retrieveResponse][:result].nil?
      raise CarrierWave::Storage::Salesforce::File::DocumentNotFound
    end
    
    body = Base64.decode64(retrieve_response[:retrieveResponse][:result][:Body])
    file_name = retrieve_response[:retrieveResponse][:result][:Name]
    [body, file_name]
  end

  def self.upload(file, uploader)
    sf_binding = login(uploader.username, uploader.password)

    blank_document = sobject("Document", nil,
      :Body     => Base64.encode64("waiting for upload..."),
      :Type     => ::File.extname(uploader.store_path),
      :Name     => ::File.basename(uploader.store_path),
      :FolderId => uploader.folder_id
    )
    creation_response = sf_binding.create(blank_document)

    document_id = creation_response[:createResponse][:result][:id]

    upload_params = :perform_upload, uploader.username, uploader.password, document_id, file.path, sf_binding
    if uploader.perform_upload
      uploader.perform_upload[self, *upload_params]
    else
      send(*upload_params)
    end
    
    document_id
  end

  def self.delete(uploader, document_id)
    sf_binding = login(uploader.username, uploader.password)
    response   = sf_binding.delete [:id, document_id]
    
    response[:deleteResponse][:result][:success] == "true"
  end
  
  def self.perform_upload(user, pass, document_id, file_path, sf_binding=nil)
    sf_binding ||= login(user, pass)
    sf_binding.update sobject("Document", document_id, :Body => Base64.encode64(IO.read(file_path)))
  end
end