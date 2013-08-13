# encoding: utf-8
require 'gpb_merchant/version'
require 'uri'

module GpbMerchant

  extend self

  def login(v = nil)

    @login = v unless v.nil?
    @login

  end # login

  def password(v = nil)

    @password = v unless v.nil?
    @password

  end # password

  def merch_id(v = nil)

    @merch_id = v unless v.nil?
    @merch_id

  end # merch_id

  def account_id(v = nil)

    @account_id = v unless v.nil?
    @account_id

  end # account_id

  def back_url_success(v = nil)

    @back_url_success = v unless v.nil?
    @back_url_success

  end # back_url_success

  def back_url_failure(v = nil)

    @back_url_failure = v unless v.nil?
    @back_url_failure

  end # back_url_failure

  def pps_url(v = nil)

    @pps_url = v unless v.nil?
    @pps_url

  end # pps_url

  # Ссылка на оплату заказа
  def url_for_payment(order_uri)

    uri = ::URI.encode_www_form({

      :LANG         => "RU",
      :merch_id     => self.merch_id,
      :back_url_s   => self.back_url_success,
      :back_url_f   => self.back_url_failure,
      "o.order_uri" => order_uri

    })

    "#{pps_url}?#{uri}"

  end # url_for_payment

  # Выставление счета
  def init_payment(order_uri)
    ::GpbTransaction.init(order_uri)
  end # init_payment

  # Проверка возможности приема платежа
  def check_payment(params)

    result, msg, id = ::GpbTransaction.check({

      trx_id:     params[:trx_id],
      merch_id:   params[:merch_id],
      order_uri:  params[:order_uri],
      amount:     params[:amount].try(:to_f) || 0,
      checked_at: ::URI.decode_www_form_component(params[:ts]).to_time rescue nil

    })

    ::GpbMerchant::XmlBuilder.check_response({

      order_id: params[:order_uri],
      merchant_trx_id: id,
      amount:   params[:amount],
      currency: 643,
      desc:     msg

    }, result)

  end # check_payment

  # Регистрация результата платежа
  def register_payment(params)

    # Разбираем время авторизационного запроса в формате «MMddHHmmss»
    m1 = String(params[:transmission_at]).match(
      /(?<month>\d{2})(?<day>\d{2})(?<hour>\d{2})(?<minute>\d{2})(?<sec>\d{2})/
    )

    # Пробуем преобразовать в дату
    transmission_at = ::Time.new(
      ::Time.now.year,
      m1[:month],
      m1[:day],
      m1[:hour],
      m1[:minute],
      m1[:sec]
    ) rescue nil

    result, msg = ::GpbTransaction.complete({

      merch_id:     params[:merch_id],
      trx_id:       params[:trx_id],
      merchant_trx: params[:merchant_trx],

      order_uri:    params[:order_uri],

      result_code:  params[:result_code].try(:to_i) || 0,
      amount:       params[:amount].try(:to_f) || 0),

      account_id:   params[:account_id],
      rrn:          params[:rrn],

      transmission_at: transmission_at,
      payed_at:     ::URI.decode_www_form_component(params[:ts]).to_time rescue nil

      card_holder:  ::URI.decode_www_form_component(params[:card_holder]),
      card_masked:  params[:card_masked],

      # TODO: пока не знаю, что с этим параметром делать
      fully_auth:   params[:fully_auth] == 'Y',

      signature:    ::URI.decode_www_form_component(params[:signature])

    })

    ::GpbMerchant::XmlBuilder.register_response({
      desc: msg
    }, result)

  end # register_payment

  # Отмена платежа
  def cancel_payment(order_uri)
    ::GpbTransaction.cancel(order_uri)
  end # cancel_payment

  # Логирование
  def log(str, mark = "GpbMerchant")

    if mark

      ::Rails.logger.tagged(mark) {
        ::Rails.logger.error(str)
      }

    else
      ::Rails.logger.error(str)
    end

    str

  end # log

end # GpbMerchant

require 'gpb_merchant/xml'
require 'gpb_merchant/engine'
require 'gpb_merchant/railtie'
