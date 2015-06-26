class WelcomeController < ApplicationController
  def index
  end

  def processbill

    login_cred = {
      'user' => "michaelrix",
      'pass' => "jumity2014"
    }
    login_url = "https://css.torontohydro.com/selfserve/Pages/login.aspx"
    login_field_names = {
      'user' => 'ctl00$SPWebPartManager1$g_70b63f08_8d15_4c19_8991_940d987b2a56$ctl00$membershipLogin$UserName',
      'pass' => 'ctl00$SPWebPartManager1$g_70b63f08_8d15_4c19_8991_940d987b2a56$ctl00$membershipLogin$Password'
    }

    mech = Mechanize.new
    mech.get(login_url)
    form = mech.page.form_with(:action=>/login.aspx/)
    form[login_field_names['user']] = login_cred['user']
    form[login_field_names['pass']] = login_cred['pass']
    form.submit(form.button_with(:value=>'Login'))
    puts mech.page.parser.css("title").text.strip
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
      File.open("torontohydro_#{opt.value}.pdf", 'wb'){|f| f << response.body}
    end
    redirect_to root_path

  end
end
