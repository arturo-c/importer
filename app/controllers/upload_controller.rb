class UploadController < ApplicationController
  def uploadFile
    post = DataFile.save(params[:upload])
    render :js => "alert('File has been uploaded');"
  end
end