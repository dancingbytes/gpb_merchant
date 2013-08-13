# encoding: utf-8
GpbMerchant::Engine.routes.draw do

  get "gpb/check"  => 'gpb#check'

  get "gpb/pay"    => 'gpb#pay'

end # draw
