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

    if page.code == 200
      #obtain bills in .pdf format
      case company
      when "t_hydro"
        mech.get('https://css.torontohydro.com/Pages/ViewBills.aspx')
        puts mech.page.parser.css("title").text.strip
        form = mech.page.form_with(:action=>/ViewBills.aspx/)
        form['ctl00$SPWebPartManager1$g_075c613b_6bec_42d8_9303_ee5f802d2cdd$ctl00$ddlStatements'] = login_cred['user']
        form[login_field_names['pass']] = login_cred['pass']
        form.submit(form.button_with(:value=>'Login'))
        field_name = 'ctl00$SPWebPartManager1$g_075c613b_6bec_42d8_9303_ee5f802d2cdd$ctl00$ddlStatements'
        form.field_with(:name=>field_name).options[0..-1].each do |opt|
          form[field_name] = opt.value
          response = form.submit(form.button_with(:value=>'Download'))
          File.open("public/torontohydro_#{opt.value}.pdf", 'wb'){|f| f << response.body}
        end
      when "union_gas"
        mech.get('https://myaccount.uniongas.com/billHistory.aspx')
        File.open('file.html', 'w'){|f| f.puts mech.page.parser.to_html}
        bills = Nokogiri::HTML(open('file.html'))
        bills.css('div.billHistoryLiteralContentCellColumn0LabelRegion a').each do |bill|
          puts "https://myaccount.uniongas.com/#{bill['href']}"
          mech.pluggable_parser.pdf = Mechanize::DirectorySaver.save_to 'public'
          mech.get("https://myaccount.uniongas.com/#{bill['href']}")
        end
      else
        redirect_to root_path
      end
   else
     puts 'Error logging in'
   end
    redirect_to root_path

  end
end
