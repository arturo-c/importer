
require 'allplayers'
require 'allplayers_imports'

class ApciController < ApplicationController
  def index
    @status = 'Disconnected'
    unless session[:apci_session].nil?
      #@session_start = session[:apci_session_start]
      test = session[:apci_session].user_get(1)
      if test.has_key?('uid')
        @status = 'Logged in : Ready'
      else
        @status = 'Logged in : Error'
      end
    end
    render :action => :index
  end

  def logout
    unless session[:apci_session].nil?
      session[:apci_session] = nil
      session[:apci_session_start] = nil
    end
    @message = 'Disconnected'
    render :action => :index
  end

  def login
    unless params[:user].nil? or params[:pass].nil?
      sess = AllPlayers::Client.new(nil, params[:env])
      sess.add_headers({:Authorization => 'Basic ' + Base64.encode64(params[:user] + ':' + params[:pass])})
      @message = 'Connected as ' + params[:user]
      @status = 'Logged in : Ready'
      session[:apci_session] = sess
      session[:apci_session_start] = Time.now
    end
    render :action => :index
  end
end
