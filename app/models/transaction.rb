# encoding: utf-8
class Transaction

  include Mongoid::Document

  TRANSACTION_STATUSES = {

    101  => 'checked',
    102  => 'payed',
    401  => 'checked error',
    402  => 'payed error'

  }.freeze

  field :trx_id       , type: String
  field :order_uri    , type: String
  field :email        , type: String
  field :first_name   , type: String
  field :last_name    , type: String
  field :patronymic   , type: String
  field :created_at   , type: Time
  field :updated_at   , type: Time
  field :card_holder  , type: String
  field :card_masked  , type: String
  field :status_code  , type: Integer, default: 101

  # Итоговая стоимость заказа
  field :price        , type: Integer


  def self.create_or_update(params,order)
    transaction = Transaction.where(trx_id: params[:trx_id])[0]
    if transaction
      transaction.updated_at    = Time.now
      transaction.card_holder   = params['p.cardholder']
      transaction.card_masked   = params['p.maskedPan']
    else
      transaction = Transaction.new
      transaction.order_uri   = order.uri
      transaction.trx_id      = params[:trx_id]
      transaction.price       = params[:amount]
      transaction.email       = order.email
      transaction.first_name  = order.first_name
      transaction.last_name   = order.last_name
      transaction.patronymic  = order.patronymic
      transaction.created_at  = Time.now
      transaction.status_code = 101
    end

    transaction.save
  end
end
