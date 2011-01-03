# Include AllPlayers client directory.
$:.unshift File.join(File.dirname(__FILE__),'../..','lib/allplayers-ruby-client/lib')

require 'apcir_import_actions'
require 'apci_rest'

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
    render :partial => 'apci_connection'
  end

  def login
    unless params[:user].nil? or params[:pass].nil?
      sess = ApcirClient.new(nil, 'vbox.allplayers.com')
      login_response = sess.login(params[:user], params[:pass])
      @message = 'Connected as ' + login_response['user']['name']
      @status = 'Logged in : Ready'
      session[:apci_session] = sess
      session[:apci_session_start] = Time.now
    end
    render :action => :index
  end

  def logout
    unless session[:apci_session].nil?
      session[:apci_session].logout
      session[:apci_session] = nil
      session[:apci_session_start] = nil
    end
    @message = 'Disconnected'
    render :action => :index
  end
end
