require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

%w[SF_USERNAME SF_PASSWORD SF_FOLDERID].each do |setting|
  if ENV[setting].blank?
    raise "ENV[#{setting}] was blank, but is required. Set via `export #{setting}='...'` from the command line."
  end
end

describe CarrierWave::Storage::Salesforce do
  before do
    CarrierWave.configure do |config|
      config.sf_username       = ENV['SF_USERNAME']
      config.sf_password       = ENV['SF_PASSWORD']
      config.sf_folder_id      = ENV['SF_FOLDERID']
      config.sf_perform_upload = nil
    end
    @uploader = CarrierWave::Uploader::Base.new
    @uploader.stub! :store_path => 'uploads/somefile/test.txt'
    
    @storage = CarrierWave::Storage::Salesforce.new(@uploader)
    @file = CarrierWave::SanitizedFile.new(file_path('test.txt'))
  end
  
  after do
    @sf_file.delete if @sf_file
  end
  
  it "should should store and retrieve the file from Salesforce" do
    @sf_file = @storage.store!(@file)
    @sf_file.read.should == @file.read
    @sf_file.file_name.should == File.basename(@file.path)
  end
  
  it "should retrieve a file" do
    @sf_file = @storage.store!(@file)
    retrieved_file = @storage.retrieve!(@sf_file.document_id)
    retrieved_file.read.should == @file.read
    retrieved_file.file_name.should == File.basename(@file.path)
  end
  
  describe "defer uploading to the #perform_upload setting" do
    context "uploading immediately" do
      it "should upload immediately" do
        CarrierWave.configure do |config|
          config.sf_perform_upload =
            lambda do |uploader_class, perform_upload_method, username, password, document_id, file_path, sf_binding|
              uploader_class.send(perform_upload_method, username, password, document_id, file_path, sf_binding)
            end
        end
        
        @sf_file = @storage.store!(@file)
        @sf_file.read.should == @file.read
        @sf_file.file_name.should == File.basename(@file.path)
      end
    end
    
    context "not uploading immediately" do
      it "should not upload immediately" do
        CarrierWave.configure do |config|
          config.sf_perform_upload = lambda{}
        end
        
        @sf_file = @storage.store!(@file)
        @sf_file.read.should == "waiting for upload..."
        @sf_file.file_name.should == File.basename(@file.path)
      end
    end
  end

  it "should delete a file" do
    @sf_file = @storage.store!(@file)
    @sf_file.delete.should == true
    lambda{
      CarrierWave::Storage::Salesforce::File.new(@uploader, @sf_file.document_id).read
    }.should raise_error(CarrierWave::Storage::Salesforce::File::DocumentNotFound)
  end
  
  it "should add configuration to the uploader" do
    CarrierWave.configure do |config|
      config.sf_username       = "user"
      config.sf_password       = "pass"
      config.sf_folder_id      = "folder"
      config.sf_perform_upload = lambda{}
      
      config.sf_username      .should == "user"
      config.sf_password      .should == "pass"
      config.sf_folder_id     .should == "folder"
      config.sf_perform_upload.should == lambda{}
    end
  end
end