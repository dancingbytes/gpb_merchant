GpbMerchant

### Config

At the file "config/gpb.rb"

GpbMerchant.login               'you_login'
GpbMerchant.password            'some_secure_password'
GpbMerchant.merch_id            '1EEDD8E6B082742B5A8943B34EB743DB'
GpbMerchant.account_id          'F5C39675D7C04691529261021286112D'
GpbMerchant.back_url_success    'https://www.you_mega_shop.com/order/success_url'
GpbMerchant.back_url_failure    'https://www.you_mega_shop.com/order/failure_url'
GpbMerchant.pps_url             'https://test.pps.gazprombank.ru/payment/start.wsm'

### Use

1. Create a bill for order
GpbMerchant.init_payment("0081793")

2. Use link
GpbMerchant.url_for_payment("0081793")

### License

Authors: crackedmind (digital.stream.of.mind@gmail.com), Tyralion (piliaiev@gmail.com)

Copyright (c) 2013 DansingBytes.ru, released under the BSD license
