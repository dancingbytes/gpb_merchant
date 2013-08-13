# encoding: utf-8
GpbMerchant::Engine.routes.draw do

  get "payments/gpb/check"  => 'gpb#check'

  get "payments/gpb/pay"    => 'gpb#pay'

end # draw
