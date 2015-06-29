class WelcomeController < ApplicationController
  def index
  end

  def processbill
    user = params[:username]
    password = params[:password]
    company = params[:company]

    #set url and field names based on selected company
    case company
    when "t_hydro"
      login_url = "https://css.torontohydro.com/selfserve/Pages/login.aspx"
      login_field_names = {
        'user' => 'ctl00$SPWebPartManager1$g_70b63f08_8d15_4c19_8991_940d987b2a56$ctl00$membershipLogin$UserName',
        'pass' => 'ctl00$SPWebPartManager1$g_70b63f08_8d15_4c19_8991_940d987b2a56$ctl00$membershipLogin$Password'
      }
    when "union_gas"
      login_url = 'https://myaccount.uniongas.com/login.aspx'
      login_field_names = {
        'user' => 'loginFrameUserIDTextBox',
        'pass' => 'loginFramePasswordTextBox'
      }
    else
      redirect_to root_path
    end

    mech = Mechanize.new { |agent|
      agent.user_agent_alias = 'Mac Safari'
      agent.log = Logger.new "mech.log"
    }

    #input credentials into fields, submit and print page title for validation
    page = mech.get(login_url)
    form = mech.page.form_with(:action=>/login.aspx/)
    form[login_field_names['user']] = user
    form[login_field_names['pass']] = password
    form.submit(form.button_with(:type=>'submit'))
    puts mech.page.parser.css("title").text.strip

    if page.code == '200'
      #obtain bills in .pdf format
      case company
      when "t_hydro"
        #download PDFs
        mech.get('https://css.torontohydro.com/Pages/ViewBills.aspx')
        puts mech.page.parser.css("title").text.strip
        form = mech.page.form_with(:action=>/ViewBills.aspx/)
        field_name = 'ctl00$SPWebPartManager1$g_075c613b_6bec_42d8_9303_ee5f802d2cdd$ctl00$ddlStatements'
        form.field_with(:name=>field_name).options[0..-1].each do |opt|
          form[field_name] = opt.value
          response = form.submit(form.button_with(:value=>'Download'))
          File.open("public/torontohydro_#{opt.value}.pdf", 'wb'){|f| f << response.body}
        end

        #retrieve summary data and table
        puts "Account Number: " + mech.page.parser.css('table.tbl_bill_summary tr:nth-child(4) span div span')[0].text
        puts "Current Balance: " + mech.page.parser.css('table.tbl_bill_summary tr:first-child table span')[1].text
        puts "Due Date: " + mech.page.parser.css('table.tbl_bill_summary tr:first-child table span')[3].text
        counter = 0
        csv_data = ""
        mech.page.parser.css('table.tbl_acc_summary tr').each{|row|
          counter = counter + 1;
          if counter == 1
            mech.page.parser.css("table.tbl_acc_summary tr:nth-child(#{counter}) th")[0..-2].each{|i| csv_data = csv_data + i.text.strip + ","}
            csv_data = csv_data + mech.page.parser.css("table.tbl_acc_summary tr:nth-child(#{counter}) th")[-1].text.strip + "\n"
          else
            mech.page.parser.css("table.tbl_acc_summary tr:nth-child(#{counter}) td")[0..-2].each{|i| csv_data = csv_data + i.text.strip + ","}
            csv_data = csv_data + mech.page.parser.css("table.tbl_acc_summary tr:nth-child(#{counter}) td")[-1].text.strip + "\n"
          end
        }
        puts csv_data

      when "union_gas"
        #Get account# and summary data
        puts "Account Number: " + mech.page.parser.xpath('//*[@id="headerAccountSelector"]/option')[0].text.strip
        puts "Current Balance: " + mech.page.parser.css("#body_content_currentAccountStatus_CurrentBalance_Data").text.strip
        puts "Due Date: " + mech.page.parser.css("#body_content_mostRecentBillSummary_AppOrLatePaymentDate_Data").text.strip
        
        #Download PDFs
        mech.get('https://myaccount.uniongas.com/billHistory.aspx')
        mech.page.parser.css('div.billHistoryLiteralContentCellColumn0LabelRegion a').each do |bill|
          puts "https://myaccount.uniongas.com/#{bill['href']}"
          # mech.pluggable_parser.pdf = Mechanize::DirectorySaver.save_to 'public'
          # mech.get("https://myaccount.uniongas.com/#{bill['href']}")
        end

        #retrieve table
        counter = 0
        csv_data = ""
        mech.page.parser.css('div.billHistoryLiteralContentCellColumn0LabelRegion a').each do |bill|
          csv_data = csv_data + bill.text.strip + "," + mech.page.parser.css('div.billHistoryLiteralContentCellColumn8LabelRegion')[counter].text.strip + "\n"
          counter = counter + 1
        end
        puts csv_data

      else
        redirect_to root_path
      end
    else
      puts 'Error logging in'
    end
    redirect_to root_path

  end
end
