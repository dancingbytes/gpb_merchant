module GpbMerchant

  class XmlBuilder


    def self.build_check_response(data, success = true)
      source = Nokogiri::XML::Builder.new do |xml|
        xml.payment_avail_response do 
          xml.result do
            xml.code("1") # ok!
            xml.desc(data[:desc])
          end
          xml.purchase do 
            xml.shortDesc(" ")
            xml.longDesc("Zakaz ##{data[:order_id]}")
            xml.account_amount do
              xml.id(::GpbMerchant::account_id)
              xml.amount(data[:amount])
              xml.currency(data[:currency])
              xml.exponent("2")
            end
          end
          xml.merchant_trx("")
        end
      end
      source.to_xml.gsub('payment_avail_response','payment-avail-response').gsub('account_amount','account-amount').gsub('merchant_trx','merchant-trx')
    end # build_check_response

    def self.build_register_response(success = true)
        
      source = Nokogiri::XML::Builder.new do |xml|
        xml.register_payment_response do
          xml.result do
            if success
              xml.code("1")
              xml.desc("OK")
            else
              xml.code("2")
              xml.desc("Temporary unavailable")
            end
          end # xml.result
        end # xml.register_payment_response
      end
      source.to_xml.gsub('register_payment_response','register-payment-response')
    end

  end

end
