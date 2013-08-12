# encoding: utf-8
require "gpb_merchant/version"

module GpbMerchant
  
  extend self

  mattr_accessor :login, :password, :merch_id, :account_id, :back_url_success, :back_url_failure, :pps_url

  def build_redirection_url(order_uri)
    "#{pps_url}?LANG=ru&merch_id=#{merch_id}&back_url_s=#{back_url_success}&back_url_f=#{back_url_failure}&o.order_uri=#{order_uri}"
  end

end # GpbMerchant

require 'gpb_merchant/xml'

if defined?(::Rails)
  require 'gpb_merchant/engine'
  require 'gpb_merchant/railtie'
end
