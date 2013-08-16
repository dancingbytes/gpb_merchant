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

  validates_presence_of   :card_holder,
    :message  => "Укажите владельца карты",
    :if       => ->() { [301].include?(self.state_code) }

  validates_presence_of   :card_masked,
    :message  => "Введите номер карты карты",
    :if       => ->() { [301].include?(self.state_code) }

  validates_uniqueness_of :order_uri,
    :scope    => [ :trx_id, :merch_id ],
    :message  => "Заказ уже находится в обработке"

  validates_numericality_of :price,
    greater_than: 0,
    message:      'Сумма оплаты должна быть больше 0',
    if:           ->() { [101].include?(self.state_code) }

  validate :valid_order?

  index({ order_uri:    1 }, { background:  true })
  index({ state_code:   1 }, { background:  true })
  index({ updated_at:   1 }, { background:  true })
  index({ fio:          1 }, { background:  true })
  index({ phone:        1 }, { background:  true })
  index({ card_holder:  1 }, { background:  true })

  index({

    trx_id:     1,
    merch_id:   1,
    order_uri:  1

  }, {

    name:     "gpbt_indx_1",
    unique:   true

  })

  # Стандартным способом запрещаем удаление записи
  before_destroy  ->() { return false }

  # При любом изменении записи обновляем дату изменения
  before_save     ->() { self.updated_at = ::Time.now.utc }

  scope :filter_by, ->(s = nil, b = nil, e = nil) {

    req = self.criteria

    req = req.where(:updated_at.gte => b.try(:to_time)) unless b.blank?
    req = req.where(:updated_at.lt  => e.try(:to_time).try(:+, 24.hours)) unless e.blank?

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

      order = Order.where(uri: order_uri).first
      return [ false, "Заказ не найден" ] unless order

      begin

        tr = new
        tr.merch_id     = ::GpbMerchant.merch_id
        tr.account_id   = ::GpbMerchant.account_id
        tr.order_uri    = order_uri
        tr.phone        = order.try(:phone_number)
        tr.fio          = order.try(:fio)
        tr.price        = (order.price * 100).to_i
        tr.state_code   = 101

        if tr.with(safe: true).save
          [ true, "Счет на оплату выставлен" ]
        else
          [ false, tr.errors.first.last || "Неизвестная ошибка" ]
        end

      rescue => e

        ::GpbMerchant.log(e.message, "GpbMerchant[init]")
        [ false, "Ошибка сервера" ]

      end

    end # init

    # Проверка платежа
    def check(params)

      tr = where({
        merch_id:   params[:merch_id],
        order_uri:  params[:order_uri]
      }).first

      return [ false, "Счет на оплату не выставлен" ] unless tr

      if tr.state_code == 201
        return [ false, "Оплата уже прошла проверку" ]
      elsif tr.state_code == 301
        return [ false, "Оплата завершена ранее" ]
      elsif tr.state_code == 401
        return [ false, "Выставленный счет отменен" ]
      end

      delta = tr.price - params[:amount].try(:to_i)

      return [false,
        "Сумма оплаты (#{params[:amount].to_f/100} руб.) не соотвествует заявленой стоиомсти заказа (#{tr.price_f} руб.)"
      ] if delta > 0 || delta < 0

      # Сохраняем данные
      tr.state_code = 201
      tr.trx_id     = params[:trx_id]
      tr.checked_at = params[:checked_at]

      begin

        if tr.with(safe: true).save
          [ true, "Оплата разрешена", tr.id.to_s ]
        else
          [ false, tr.errors.first.last || "Неизвестная ошибка" ]
        end

      rescue => e

        ::GpbMerchant.log(e.message, "GpbMerchant[check]")
        [ false, "Ошибка сервера" ]

      end

    end # check

    # Проведение платежа
    def complete(params)

      tr = where({
        merch_id:   params[:merch_id],
        order_uri:  params[:order_uri],
        trx_id:     params[:trx_id]
      }).first

      return [ false, "Счет на оплату не выставлен" ] unless tr

      if tr.state_code == 101
        return [ false, "Необходимо произвезти проверку платежа" ]
      elsif tr.state_code == 301
        return [ false, "Оплата завершена ранее" ]
      elsif tr.state_code == 401
        return [ false, "Выставленный счет отменен" ]
      elsif tr.id.to_s != params[:merchant_trx]
        return [ false, "Неверный идентификатор операции" ]
      end

      delta = tr.price - params[:amount].try(:to_i)

      return [false,
        "Сумма оплаты (#{params[:amount].to_f/100} руб.) не соотвествует заявленой стоиомсти заказа (#{tr.price_f} руб.)"
      ] if delta > 0 || delta < 0

      # Сохраняем данные
      tr.state_code   = (params[:result_code] == 1 ? 301 : 402)
      tr.payed_at     = params[:payed_at]
      tr.transmission_at = params[:transmission_at]
      tr.account_id   = params[:account_id]
      tr.rrn          = params[:rrn]
      tr.card_holder  = params[:card_holder]
      tr.card_masked  = params[:card_masked]

      begin

        if tr.with(safe: true).save
          [ true, tr.state_code == 301 ? "Оплата успешна" : "Счет на оплату отменен" ]
        else
          [ false, tr.errors.first.last || "Неизвестная ошибка" ]
        end

      rescue => e

        ::GpbMerchant.log(e.message, "GpbMerchant[complete]")
        [ false, "Ошибка сервера" ]

      end

    end # complete

    # Отмена платежа
    def cancel(order_uri)

      tr = where({
        merch_id:  ::GpbMerchant.merch_id,
        order_uri: order_uri
      }).first

      return [ false, "Счет не был выставлен для указанного заказа." ] unless tr

      tr.state_code = 401 # отмена

      begin

        if tr.with(safe: true).save
          [ true, "Счет на оплату отменен" ]
        else
          [ false, tr.errors.first.last || "Неизвестная ошибка" ]
        end

      rescue => e

        ::GpbMerchant.log(e.message, "GpbMerchant[cancel]")
        [ false, "Ошибка сервера" ]

      end

    end # cancel

  end # class << self

  def order
    @order ||= ::Order.where(uri: self.order_uri).first
  end # order

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
