# encoding: utf-8
module GpbMerchant

  module XmlBuilder

    extend self

    def check_response(data, success = true)

      create_xml do |xml|

        xml.send(:"payment-avail-response") do

          if success

            xml.result do

              xml.code  "1" # ok!
              xml.desc  xml_escape(data[:desc])

            end # result

            xml.send(:"merchant-trx", data[:merchant_trx_id])

            xml.purchase do

              xml.shortDesc "Заказ № #{data[:order_uri]}"
              xml.longDesc  "Олата за заказ № #{data[:order_uri]}"

              xml.send(:"account-amount") do

                xml.id        ::GpbMerchant::account_id
                xml.amount    data[:amount]
                xml.currency  data[:currency]
                xml.exponent  "2"

              end # account-amount

            end # purchase

          else

            xml.result do

              xml.code   '2'
              xml.desc  xml_escape(data[:desc])

            end # result

          end # if

        end # payment-avail-response

      end # create_xml

    end # check_response


    def register_response(data, success = true)

      create_xml do |xml|

        xml.send(:"register-payment-response") do

          xml.result do

            if success

              xml.code  "1"
              xml.desc  "OK"

            else

              xml.code  "2"
              xml.desc  xml_escape(data[:desc])

            end # if

          end # result

        end # register-payment-response

      end # create_xml

    end # register_response

    private

    def create_xml(&block)

      source = Nokogiri::XML::Builder.new(:encoding => 'UTF-8', &block)
      source.to_xml

    end # create_xml

    def xml_escape(str)

      str
        .gsub(/&/, "&amp;")
        .gsub(/'/, "&apos;")
        .gsub(/"/, "&quot;")
        .gsub(/>/, "&gt;")
        .gsub(/</, "&lt;")

    end # xml_escape

  end # XmlBuilder

end # GpbMerchant
