# encoding: utf-8
class GpbController < ApplicationController

  layout false

  unloadable

  before_filter :validate_merch_id, :auth_request

  def check

    render xml: ::GpbMerchant.check_payment({

      trx_id:     params['trx_id'],
      merch_id:   params['merch_id'],
      order_uri:  params['o.order_uri'],
      amount:     params['o.amount']

    })

  end # check

  def pay

    render xml: ::GpbMerchant.register_payment({

      merch_id:     params['merch_id'],
      trx_id:       params['trx_id'],
      merchant_trx: params['merchant_trx'],

      order_uri:    params['o.order_uri'],

      result_code:  params['result_code'],
      amount:       params['o.amount'],

      account_id:   params['account_id'],
      rrn:          params['p.rrn'],

      transmission_at: params['p.transmissionDateTime'],
      payed_at:     params['td']

      card_holder:  params['p.cardholder'],
      card_masked:  params['p.maskedPan'],

      fully_auth:   params['p.isFullyAuthenticated'],

      signature:    params['signature']

    })

  end # pay

  private

  def validate_merch_id

    return true ((::GpbMerchant::merch_id == params[:merch_id]) && (params[:merch_id] != ""))

    respond_to do |format|
      format.html { render :text => "Неверный запрос", :status => 400, :layout => false }
      format.any  { head 400 }
    end

    false

  end # validate_merch_id

  def auth_request

    authenticate_or_request_with_http_basic do |login, password|
      (login == ::GpbMerchant::login && password == ::GpbMerchant::password)
    end

  end # auth_request

end # GpbController
