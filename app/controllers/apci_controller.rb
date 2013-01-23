# Include AllPlayers client directory.
$:.unshift File.join(File.dirname(__FILE__),'../..','lib/allplayers-ruby-client/lib')

require 'apcir_import_actions'
require 'apci_rest'
require 'oauth'

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
    session[:apci_session].logout
    unless session[:apci_session].nil?
      session[:apci_session] = nil
      session[:apci_session_start] = nil
    end
    @message = 'Disconnected'
    render :action => :index
  end

  def login
    unless params[:user].nil? or params[:pass].nil?
      sess = ApcirClient.new(nil, params[:env])
      login_response = sess.login(params[:user], params[:pass])
      #sess.add_headers({:Authorization => 'Basic ' + Base64.encode64(params[:user] + ':' + params[:pass])})
      @message = 'Connected as ' + params[:user]
      @status = 'Logged in : Ready'
      session[:apci_session] = sess
      session[:apci_session_start] = Time.now
    end
    render :action => :index
  end


  def login_oauth
    consumer_key = "3Q88vpe2kjyyFJedJ9TNigKGZUtF5vCW"
    consumer_secret = "QcZLNL4yik83h6PPycbpMwcU5UapChat"
    session[:environment] = params[:environment]
    consumer = OAuth::Consumer.new(consumer_key, consumer_secret,
      :site => "https://" + params[:environment],
      :request_token_path => "/oauth/request_token",
      :authorize_path => "/oauth/authorize",
      :access_token_path => "/oauth/access_token",
      :http_method => :get)
    request_token = consumer.get_request_token
    session[:request_token] = request_token
    render :update do |page|
      page.redirect_to request_token.authorize_url + "&oauth_callback=" + CGI.escape("http://10.40.10.156:3000/apci/oauth")
    end
  end

  def oauth
    request_token = session[:request_token]
    access_token = request_token.get_access_token
    sess = ApcirClient.new(nil, session[:environment], 'https://', 'oauth', access_token)
    session[:apci_session] = sess
    session[:apci_session_start] = Time.now
    redirect_to '/'
  end
end
