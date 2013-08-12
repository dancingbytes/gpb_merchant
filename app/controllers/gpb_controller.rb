class GpbController < ApplicationController
  layout false

  unloadable


  before_filter -> do 
    authenticate_or_request_with_http_basic do |login, password|
      (login == ::GpbMerchant::login && password == ::GpbMerchant::password)
    end
  end

  before_filter -> { raise 'unknown merch_id' if ::GpbMerchant::merch_id != params[:merch_id] }

  def check
    
    success = true    
    order = Order.where(uri: params['o.order_uri']).first
    success = false unless order

    Transaction.create_or_update(params,order) if order
    render xml: GpbMerchant::XmlBuilder.build_check_response({order_id: order.uri, amount: order.price, currency: 643, desc: ''}, success)
  end

  def pay
    success = true    
    order = Order.where(uri: params['o.order_uri']).first
    success = false unless order

    Transaction.create_or_update(params,order)
    render xml: GpbMerchant::XmlBuilder.build_register_response(success)
  end
end
