require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe CarrierWave::Storage::Salesforce do
  before do
    @uploader = mock('an uploader',
      :username       => ENV['SF_USERNAME'],
      :password       => ENV['SF_PASSWORD'],
      :folder_id      => ENV['SF_FOLDERID'],
      :store_path     => 'uploads/somefile/test.txt',
      :perform_upload => nil
    )
    
    @storage = CarrierWave::Storage::Salesforce.new(@uploader)
    @file = CarrierWave::SanitizedFile.new(file_path('test.txt'))
  end
  
  after do
    # delete any files uploaded, mmmkay?
  end
  
  #todo: test that setting uploader.perform_upload to a proc works
  it "should should store and retrieve the file from Salesforce" do
    sf_file = @storage.store!(@file)
    sf_file.read.should == @file.read
    sf_file.file_name.should == File.basename(@file.path)
  end
  
  describe "defer uploading to the #perform_upload setting" do
    context "uploading immediately" do
      it "should upload immediately" do
        @uploader.stub!(
          :perform_upload =>
            lambda do |uploader_class, perform_upload_method, username, password, document_id, file_path, sf_binding|
              uploader_class.send(perform_upload_method, username, password, document_id, file_path, sf_binding)
            end
        )
        
        sf_file = @storage.store!(@file)
        sf_file.read.should == @file.read
        sf_file.file_name.should == File.basename(@file.path)
      end
    end
    
    context "not uploading immediately" do
      it "should not upload immediately" do
        @uploader.stub!(:perform_upload => lambda{})
        
        sf_file = @storage.store!(@file)
        sf_file.read.should == "waiting for upload..."
        sf_file.file_name.should == File.basename(@file.path)
      end
    end
  end
end