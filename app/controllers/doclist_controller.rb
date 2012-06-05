# Copyright (C) 2009 Google Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'apci_controller'
require 'yaml'
require 'gdoc_to_apci'

class DoclistController < ApplicationController
  layout 'standard'
  before_filter :setup_client, :set_user_email

  def all
    url = params[:url] ? params[:url] + "/-/#{MINE_LABEL}" :
                         DOCLIST_FEED + "/-/#{SPREADSHEET_DOC_TYPE}"
    url += '?showfolders=true'

    begin
      feed = @client.get(url).to_xml
      @documents = create_docs(feed)
      @doc_type = SPREADSHEET_DOC_TYPE
    rescue GData::Client::AuthorizationError
      logout
    end

    if !request.xhr?
      render :action => 'documents'
    else
      render :partial => 'documents_list'
    end
  end

  def documents
    #@doc_type = DOCUMENT_DOC_TYPE
    @doc_type = SPREADSHEET_DOC_TYPE
    get_documents_for(:category => [@doc_type])
  end

  def spreadsheets
    @doc_type = SPREADSHEET_DOC_TYPE
    get_documents_for(:category => [@doc_type])
  end

  def presentations
    @doc_type = PRESO_DOC_TYPE
    get_documents_for(:category => [@doc_type])
  end

  def pdfs
    @doc_type = PDF_DOC_TYPE
    get_documents_for(:category => [@doc_type])
  end

  def folders
    @doc_type = FOLDER_DOC_TYPE
    get_documents_for(:category => [@doc_type],
                      :params=>'showfolders=true')
  end

  def starred
    @doc_type = DOCUMENT_DOC_TYPE
    get_documents_for(:category => [STARRED_LABEL],
                      :params=>'showfolders=true')
  end

  def trashed
    @doc_type = DOCUMENT_DOC_TYPE
    get_documents_for(:category => [TRASHED_LABEL],
                      :params=>'showfolders=true')
  end

  def show
    # TODO - It would be nice to cache something here some we don't fetch three
    # feeds for one page load.
    #
    # expandAcl projection will inline the ACLs in the resulting feed
    url = params[:url].sub(/\/full/, '/expandAcl')

    doc_feed = @client.get(url).to_xml
    @document = create_doc(doc_feed)
    if @document.type == DOCUMENT_DOC_TYPE or @document.type == PRESO_DOC_TYPE
      export_url = @document.links['export'] + '&exportFormat=png'
      # Src value for an image containing a data URI
      @preview_img = Base64.encode64(download(export_url))
    end

    # TODO - Parse worksheets, move this to separate function.
    @worksheets = []
    if @document.links.has_key?('http://schemas.google.com/spreadsheets/2006#worksheetsfeed')
      uri = @document.links['http://schemas.google.com/spreadsheets/2006#worksheetsfeed']
      ws_feed = @client.get(uri).to_xml
      # Select each entry with a title.
      ws_feed.elements.each('entry/title/..') do |entry|
        worksheet = {:title => entry.elements['title'].text}
        worksheet[:cells_uri] = entry.elements["link[@rel='http://schemas.google.com/spreadsheets/2006#cellsfeed')]"].attributes['href']
        puts worksheet.to_yaml
        @worksheets.push(worksheet) if !entry.nil?
      end
    end

    # TODO - Grab specific worksheet, move to separate function.
    if params.has_key?(:worksheet)
      @worksheet_uri = params[:worksheet]
      cells = @client.get(@worksheet_uri).to_xml
      @worksheet = worksheet_feed_to_a(cells)
    else
      @worksheet_uri = ''
    end

    render :partial => 'show'
  end

  def import
    if params.has_key?(:worksheet)
      #MiddleMan.worker(:imports_worker).async_import_worksheet(:arg => 'cheese')
      #MiddleMan.worker(:imports_worker).enq_some_task(:arg => "persisting job",:job_key => "hgfhjh")
      logger_level = nil
      @sheet = params[:stitle]
      @wsheet = params[:wtitle]
      @worksheet_uri = params[:worksheet]
      @apci_session = session[:apci_session]
      path = Dir.pwd + '/import_logs'
      begin
        FileUtils.mkdir(path)
      rescue
        # Do nothing, it's already there?  Perhaps you should catch a more specific
        # message.
      ensure
        log_suffix = @sheet + ' ' + Time.now.strftime("%Y-%m-%d_%H_%M")
        #
        rest_logger = Logger.new(path + '/rest_' + log_suffix + '.log')
        rest_logger.formatter = Logger::Formatter.new
        rest_logger.level = Logger::DEBUG
        logdev = ApciLogDevice.new(path + '/import_' + log_suffix + '.csv',
          :shift_age => 0, :shift_size => 1048576)
        logger = Logger.new(logdev)
        logger.formatter = ApciFormatter.new
        logger.level = logger_level.nil? ? Logger::DEBUG : logger_level
      end
      entry3 = <<-EOF
            <entry xmlns="http://www.w3.org/2005/Atom"
            xmlns:gs="http://schemas.google.com/spreadsheets/2006">
              <gs:rowCount>50</gs:rowCount>
              <gs:colCount>5</gs:colCount>
            EOF
      entry3 = entry3 + '<title>test import_' + Time.now.strftime("%Y-%m-%d %H:%M") + '</title></entry>'
      #resp2 = @client.post(params[:sheeturi], entry3)
      # End Logging.
      @apci_session.log(rest_logger)

      # Extend our API class with import and interactive actions.
      @apci_session.extend ImportActions
      @apci_session.logger = logger
      cells_xml = @client.get(@worksheet_uri).to_xml
      worksheet = worksheet_feed_to_a(cells_xml)
      @apci_session.import_sheet(worksheet, @wsheet)
      @apci_session.logger = nil
      @apci_session.log(nil)
      rest_logger.close
      logger.close
    end
    show
  end

  def download(export_url=nil)
    export_url ||= params[:export_url]

    resp = @client.get(export_url)

    # Set our response headers based on those returned with the file.
    headers['content-type'] = resp.headers['content-type']
    headers['content-disposition'] = resp.headers['content-disposition']

    if params[:export_url]
      render :text => resp.body
    else
      return resp.body
    end
  end
  
  def download_log()
    send_file "#{RAILS_ROOT}/import_logs/" + params[:logfile], :filename => params[:logfile], :type=>"application/csv"
  end

  def set_acls
    return unless request.xhr?

    @html, @errors = [], []
    @role = params[:role] || 'writer'

    if !params[:emails].nil?
      for email in params[:emails]
        entry = <<-EOF
          <entry xmlns='http://www.w3.org/2005/Atom'
                 xmlns:gAcl='http://schemas.google.com/acl/2007'>
            <category scheme='http://schemas.google.com/g/2005#kind'
                      term='http://schemas.google.com/acl/2007#accessRule'/>
            <gAcl:role value='#{@role}'/>
            <gAcl:scope type='user' value='#{email}'/>
          </entry>
        EOF
        begin
          resp = @client.post(params[:acl_feedlink], entry)
          @html.push("<li>#{email}</li>")
        rescue
          @errors.push(email)
        end
      end
    else
      render :update do |page|
        page.call "$('save_loading').toggleClassName", 'hidden'
        page.alert "You didn't select anyone to be a #{@role}"
      end
    end
  end

  def logout
    @client.auth_handler.revoke
    session[:users_email] = nil
    session[:token] = nil

    redirect_to '/'
  end

private

  def set_user_email
    # Query feed to fetch user's email
    if session[:users_email].nil?
      feed = @client.get(DOCLIST_FEED + '?max-results=0').to_xml
      session[:users_email] = feed.elements['author/email'].text
    end
  end

  def create_doc(entry)
    resource_id = entry.elements['gd:resourceId'].text.split(':')
    doc = GDoc::Document.new(entry.elements['title'].text,
                             :type => resource_id[0],
                             :xml => entry.to_s)

    doc.doc_id = resource_id[1]
    doc.last_updated = DateTime.parse(entry.elements['updated'].text)
    if !entry.elements['gd:lastViewed'].nil?
      doc.last_viewed = DateTime.parse(entry.elements['gd:lastViewed'].text)
    end
    if !entry.elements['gd:lastModifiedBy/email'].nil?
       doc.last_modified_by = entry.elements['gd:lastModifiedBy/email'].text
    end
    doc.writers_can_invite = entry.elements['docs:writersCanInvite'].attributes['value']
    doc.author = entry.elements['author/email'].text

    entry.elements.each('link') do |link|
      doc.links[link.attributes['rel']] = link.attributes['href']
    end
    doc.links['acl_feedlink'] = entry.elements['gd:feedLink'].attributes['href']
    doc.links['content_src'] = entry.elements['content'].attributes['src']

    case doc.type
      when DOCUMENT_DOC_TYPE, PRESO_DOC_TYPE
        doc.links['export'] = DOCLIST_SCOPE +
                              "download/documents/Export?docID=#{doc.doc_id}"
      when SPREADSHEET_DOC_TYPE
        doc.links['export'] = SPREADSHEETS_SCOPE +
                              "download/spreadsheets/Export?key=#{doc.doc_id}"
      when PDF_DOC_TYPE
        doc.links['export'] = doc.links['content_src']
    end

    entry.elements.each('gd:feedLink/feed/entry') do |feedlink_entry|
      email = feedlink_entry.elements['gAcl:scope'].attributes['value']
      role = feedlink_entry.elements['gAcl:role'].attributes['value']
      doc.add_permission(email, role)
    end
    return doc
  end

  def create_docs(feed)
    documents = []
    feed.elements.each('entry') do |entry|
      doc = create_doc(entry)
      documents.push(doc) if !doc.nil?
    end
    return documents
  end

  def get_documents_for(options={})
    options[:category] ||= [MINE_LABEL]

    begin
      uri = DOCLIST_FEED + "/-/#{options[:category].join('/')}"
      uri += "?#{options[:params]}" if options[:params]
      feed = @client.get(uri).to_xml
      @documents = create_docs(feed)
    rescue GData::Client::AuthorizationError
      logout
    end

    #XMLHttpRequest
    unless request.xhr?
      render :action => 'documents'
    else
      render :partial => 'documents_list'
    end
  end

  # Traverse worksheet xml feed looking for cells and save them into a 2d array.
  def worksheet_feed_to_a(xml)
    worksheet = []
    xml.elements.each('entry/gs:cell') do | cell |
      row = cell.attributes['row'].to_i - 1
      col = cell.attributes['col'].to_i - 1
      worksheet[row] = [] if worksheet[row].nil?
      worksheet[row][col] = cell.text
    end
    worksheet
  end

end
