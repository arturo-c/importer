# Include AllPlayers client directory.
$:.unshift File.join(File.dirname(__FILE__),'../..','lib/allplayers-ruby-client/lib')

require 'apcir_import_actions'
require 'apci_rest'

class ImportsWorker < BackgrounDRb::MetaWorker
  set_worker_name :imports_worker
  def create(args = nil)
    # this method is called, when worker is loaded for the first time
  end

  def import_worksheet(worksheet)
    logger.info 'ws: ' + worksheet.to_s
    logger.info 'import task ' + Time.now.to_s
  end
end

