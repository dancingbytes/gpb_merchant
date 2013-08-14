# encoding: utf-8
GpbMerchant::Engine.routes.draw do

  get "gbp/check"  => 'gpb#check'

  get "gbp/pay"    => 'gpb#pay'

end # draw
