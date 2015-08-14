# encoding: utf-8
class GpbTransaction

  include Mongoid::Document

  STATUSES = {

    101  => 'init',
    201  => 'checked',
    301  => 'payed',
    401  => 'canceled',
    402  => 'rejected'

  }.freeze


  # Идентификатор транзакции в PPS
  field :trx_id       , type: String

  # Идентификатор магазина в PPS
  field :merch_id     , type: String

  # Номер заказа
  field :order_uri    , type: String

  # Телефон плательщика
  field :phone        , type: String

  # ФИО плательщика
  field :fio          , type: String

  # Дата создания операции
  field :created_at   , type: Time,     default: ->() { ::Time.now.utc }

  # Дата последнего обновления
  field :updated_at   , type: Time,     default: ->() { ::Time.now.utc }

  # Дата проверки возможности платежа
  field :checked_at   , type: Time

  # Дата регистрации (проведения) платежа
  field :payed_at     , type: Time

  # Примерная дата (с точностью до дня) поступления платежа в банк
  field :received_at     , type: Time

  # Дата авторизационного запроса
  field :transmission_at, type: Time

  # Идентификатор счета в PPS, на который был осуществлен перевод денег
  field :account_id   , type: String

  # Идентификатор платежа в ПЦ банка-эквайера
  field :rrn          , type: String

  # Владелец карты
  field :card_holder  , type: String

  # Маскировочный номер карты
  field :card_masked  , type: String

  # Статус операции
  field :state_code  , type: Integer,   default: 101

  # Итоговая стоимость заказа в копейках
  field :price       , type: Integer,   default: 0


  validates_presence_of   :trx_id,
    :message  => "Не задан идентификатор транзакции pps",
    :if       => ->() { [201, 301].include?(self.state_code) }

  validates_presence_of   :merch_id,
    :message  => "Не задан идентификатор магазина pps"

  validates_presence_of   :order_uri,
    :message  => "Не задан номер заказа"

  validates_uniqueness_of :order_uri,
    :scope    => [ :merch_id ],
    :message  => "Заказ уже находится в обработке"

  validates_numericality_of :price,
    greater_than: 0,
    message:      'Сумма оплаты должна быть больше 0',
    if:           ->() { [101].include?(self.state_code) }

  validate :valid_order?

  index({ order_uri:    1 }, { background:  true })
  index({ state_code:   1 }, { background:  true })
  index({ received_at:  1 }, { background:  true })
  index({ fio:          1 }, { background:  true })
  index({ phone:        1 }, { background:  true })
  index({ card_holder:  1 }, { background:  true })

  index({

    merch_id:   1,
    order_uri:  1

  }, {

    name:     "gpbt_indx_1",
    unique:   true

  })

  index({

    trx_id:     1,
    merch_id:   1,
    order_uri:  1

  }, {

    name:     "gpbt_indx_2",
    background:   true

  })

  # Стандартным способом запрещаем удаление записи
  before_destroy  ->() { return false }

  # При любом изменении записи обновляем дату изменения
  before_save     ->() { self.updated_at = ::Time.now.utc }

  scope :filter_by, ->(s = nil, b = nil, e = nil) {

    req = self.criteria

    b = b.try(:to_time).try(:utc)
    e = e.try(:to_time).try(:+, 24.hours).try(:utc)

    req = req.where(:received_at.gte => b) unless b.blank?
    req = req.where(:received_at.lt  => e) unless e.blank?

    s.clean_whitespaces!

    unless s.blank?

      re = ::Regexp.escape(s)

      req = req.any_of({
        order_uri: s
      }, {
        fio: /#{re}/i,
      }, {
        phone: /#{re}/i
      }, {
        card_holder: /#{re}/i
      })

    end

    req

  } # filter_by

  class << self

    # Инициализация платежа. Выставление счета
    def init(order_uri)

      order = Order.where({ uri: order_uri }).first
      return [

        false,
        "Заказ не найден"

      ] unless order

      if (tr = where({ order_uri:  order_uri }).first)

        unless tr.invoice_for_payment?
          return [ false, "Счет на оплату уже выставлен" ]
        end

        if tr.invoice_for_payment
          return [ true, "Счет на оплату выставлен" ]
        else

          return [

            false,
            GpbMerchant.log(
              tr.errors.first.last || "Неизвестная ошибка",
              "GpbTransaction.init [#{order_uri}]"
            )

          ]

        end

      end # tr

      begin

        tr = new
        tr.merch_id     = ::GpbMerchant.merch_id
        tr.account_id   = ::GpbMerchant.account_id
        tr.order_uri    = order_uri
        tr.phone        = (order.try(:phone_number) || "").gsub(/\D/, "")
        tr.fio          = order.try(:fio)
        tr.price        = (order.price * 100).to_i
        tr.state_code   = 101

        if tr.with(safe: true).save

          return [

            true,
            "Счет на оплату выставлен"

          ]

        else

          [

            false,
            GpbMerchant.log(
              tr.errors.first.last || "Неизвестная ошибка",
              "GpbTransaction.init [#{order_uri}]"
            )

          ]

        end

      rescue => e

        ::GpbMerchant.log(e.message, "GpbTransaction.init [#{order_uri}]")
        return [

          false,
          "Ошибка сервера"

        ]

      end

    end # init

    # Проверка платежа
    def check(params = {})

      tr = where({
        merch_id:   params[:merch_id],
        order_uri:  params[:order_uri]
      }).first

      return [

        false,
        "Счет на оплату не выставлен"

      ] unless tr

      if tr.state_code == 301

        return [

          false,
          GpbMerchant.log(
            "Оплата завершена ранее",
            "GpbTransaction.check [#{params.inspect}]"
          )

        ]

      elsif tr.state_code == 401

        return [

          false,
          GpbMerchant.log(
            "Выставленный счет отменен",
            "GpbTransaction.check [#{params.inspect}]"
          )

        ]

      end

      delta = tr.price - params[:amount].try(:to_i)

      return [

        false,
        GpbMerchant.log(
          "Сумма оплаты (#{params[:amount].to_f/100} руб.) не соотвествует " <<
          "заявленой стоиомсти заказа (#{tr.price_f} руб.)",
          "GpbTransaction.check [#{params.inspect}]"
        )

      ] if delta.abs > 0

      # Сохраняем данные
      tr.state_code = 201
      tr.trx_id     = params[:trx_id]
      tr.checked_at = params[:checked_at]

      begin

        if tr.with(safe: true).save

          return [

            true,
            "Оплата разрешена", tr.id.to_s

          ]

        else

          return [

            false,
            GpbMerchant.log(
              tr.errors.first.last || "Неизвестная ошибка",
              "GpbTransaction.check [#{params.inspect}]"
            )

          ]

        end

      rescue => e

        ::GpbMerchant.log(e.message, "GpbTransaction.check [#{params.inspect}]")
        return [

          false,
          "Ошибка сервера"

        ]

      end

    end # check

    # Проведение платежа
    def complete(params)

      return [

        false,
        GpbMerchant.log(
          "Сигнатура не прошла проверку",
          "GpbTransaction.complete [#{params.inspect}]"
        )

      ] unless params[:verified]

      tr = where({
        merch_id:   params[:merch_id],
        order_uri:  params[:order_uri],
        trx_id:     params[:trx_id]
      }).first

      return [

        false,
        GpbMerchant.log(
          "Счет на оплату не выставлен",
          "GpbTransaction.complete [#{params.inspect}]"
        )

      ] unless tr

      if tr.state_code == 101

        return [

          false,
          GpbMerchant.log(
            "Необходимо произвезти проверку платежа",
            "GpbTransaction.complete [#{params.inspect}]"
          )

        ]

      elsif tr.state_code == 301

        return [

          false,
          GpbMerchant.log(
            "Оплата завершена ранее",
            "GpbTransaction.complete [#{params.inspect}]"
          )

        ]

      elsif tr.state_code == 401

        return [

          false,
          GpbMerchant.log(
            "Выставленный счет отменен",
            "GpbTransaction.complete [#{params.inspect}]"
          )

        ]

      elsif tr.id.to_s != params[:merchant_trx]

        return [

          false,
          GpbMerchant.log(
            "Неверный идентификатор операции",
            "GpbTransaction.complete [#{params.inspect}]"
          )

        ]

      end

      delta = tr.price - params[:amount].try(:to_i)

      return [

        false,
        GpbMerchant.log(
          "Сумма оплаты (#{params[:amount].to_f/100} руб.) " <<
          "не соотвествует заявленой стоиомсти заказа (#{tr.price_f} руб.)",
          "GpbTransaction.complete [#{params.inspect}]"
        )

      ] if delta.abs > 0

      # Сохраняем данные
      tr.state_code   = ((params[:result_code].try(:to_i) || 0) == 1 ? 301 : 402)
      tr.payed_at     = params[:payed_at]
      tr.received_at  = ::GpbMerchant.correct_date(params[:payed_at])
      tr.transmission_at = params[:transmission_at]
      tr.account_id   = params[:account_id]
      tr.rrn          = params[:rrn]
      tr.card_holder  = params[:card_holder]
      tr.card_masked  = params[:card_masked]

      begin

        if tr.with(safe: true).save

          if tr.state_code == 301

            # Переводим заказ в статус "Оплачено" (если задано)
            clb = ::GpbMerchant.success_payment_callback
            clb.call(tr.order_uri, tr.received_at) if clb.is_a?(::Proc)

            return [

              true,
              "Оплата успешна"

            ]

          else

            # Переводим заказ в статус "Отменено" (если задано)
            clb = ::GpbMerchant.failure_payment_callback
            clb.call(tr.order_uri) if clb.is_a?(::Proc)

            return [

              true,
              GpbMerchant.log(
                "Счет на оплату отклонен",
                "GpbTransaction.complete [#{params.inspect}]"
              )

            ]

          end

        else

          return [

            false,
            GpbMerchant.log(
              tr.errors.first.last || "Неизвестная ошибка",
              "GpbTransaction.complete [#{params.inspect}]"
            )

          ]

        end

      rescue => e

        ::GpbMerchant.log(e.message, "GpbTransaction.complete [#{params.inspect}]")

        return [

          false,
          "Ошибка сервера"

        ]

      end

    end # complete

    # Отмена платежа, при условии что счет только выставлен и
    # операции по счету еще не проводились
    def cancel(order_uri)

      tr = where({
        merch_id:  ::GpbMerchant.merch_id,
        order_uri: order_uri
      }).first

      return [

        true,
        "Счет не был выставлен для указанного заказа."

      ] unless tr

      # Если операций по счету еще не производилось -- удаляем данные
      if tr.state_code <= 101
        tr.delete
        return [ true, "Счет на оплату удален." ]
      else
        return [ false, "Отмена не возможна, уже произведены операции по счету." ]
      end # if

    end # cancel

    # Состояние транзакции
    def status(params)

      tr = where({
        merch_id:   params[:merch_id],
        order_uri:  params[:order_uri]
      }).first

      tr ? tr.state_code : 0

    end # status

  end # class << self

  def invoice_for_payment

    return false if self.order.nil?

    self.checked_at   = nil
    self.payed_at     = nil
    self.transmission_at = nil

    self.account_id   = nil
    self.rrn          = nil

    self.card_holder  = nil
    self.card_masked  = nil

    self.merch_id     = ::GpbMerchant.merch_id
    self.account_id   = ::GpbMerchant.account_id
    self.phone        = (self.order.phone_number || "").gsub(/\D/, "")
    self.fio          = self.order.fio
    self.price        = (self.order.price * 100).to_i
    self.state_code   = 101

    self.with(safe: true).save

  end # invoice_for_payment

  def invoice_for_payment?
    [401, 402].include?(self.state_code)
  end # invoice_for_payment?

  def order
    @order ||= ::Order.where(uri: self.order_uri).first
  end # order

  def state_name

    case self.state_code.try(:to_i)

      when 101 then
        "Счет выставлен"

      when 201 then
        "Проверено"

      when 301 then
        "Оплачено"

      when 401 then
        "Отменено"

      when 402 then
        "Отклонено"

      else
        "Неизвестно"

    end # case

  end # state_name

  def price_f
    (self.price.to_f / 100).round(2)
  end # price_f

  def checked?
    self.state_code >= 201
  end # checked?

  def accepted?
    self.state_code == 301
  end # accepted?

  def canceled?
    self.state_code == 401
  end # canceled?

  def rejected?
    self.state_code == 402
  end # rejected?

  private

  def valid_order?

    return true unless self.order.nil?

    self.errors.add(:order_uri, "Заказ не найден")
    false

  end # valid_order?

end # GpbTransaction
