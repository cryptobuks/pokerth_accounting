#!/usr/bin/ruby
#(c) 2015 by sacarlson  sacarlson_2000@yahoo.com
require 'sys/proctable'
include Sys
require 'sqlite3'
require './class_payment'
# be sure to install these packages before you run this:
# sudo apt-get install ruby-full sqlite3 ruby-sqlite3
# gem install sys-proctable

account_log_file="account_log.pdb"
log_dir=File.expand_path('~/.pokerth/log-files/')+"/"
account_dir=File.expand_path('~/.pokerth/accounts/')+"/"
Dir.mkdir(account_dir) unless File.directory?(account_dir)
full_account_log_file=account_dir+account_log_file


# these values were just for function test setup only
log_file="/home/sacarlson/.pokerth/log-files/pokerth-log-2015-06-30_143148.pdb"
playername="sacarlson2"
amount=100
start_cash=10000
gamenumber=7
win_count=0
handID = 1


def send_surething_player_acc(playernick,stellar_acc)
  url = "test.surething.biz/player_list" 
  postdata = RestClient.get url + "?playernick=" + playernick +"&account="+ stellar_acc
  return JSON.parse(postdata)
end

def update_players_accounts(full_account_log_file, playernick, stellar_acc)
  puts "#{full_account_log_file}"
  data = send_surething_player_acc(playernick,stellar_acc)
  db = SQLite3::Database.open full_account_log_file
  data.each do |row|
    #puts "row = #{row}"
    #puts "#{row[1] +"  " + row[2]}"
    playername = row[1]
    stellar_acc = row[2]
    db.execute "INSERT or REPLACE INTO Players VALUES(NULL,'#{playername}',NULL,'#{stellar_acc}',NULL,NULL, NULL,NULL)"
  end
  db.close if db
end


def playername_info(playername, full_account_log_file)
  db = SQLite3::Database.open full_account_log_file
  db.execute "PRAGMA journal_mode = WAL"
  stm = db.prepare "SELECT * FROM Players WHERE Name = '#{playername}' LIMIT 1" 
  rs = stm.execute
  rs.each do |row|
    #puts "row = #{row}"
    return row
  end 
end

def playername_to_secret(playername, full_account_log_file)
  return playername_info(playername, full_account_log_file)[4].to_s
end

def playername_to_accountID(playername, full_account_log_file)
  return playername_info(playername, full_account_log_file)[3].to_s
end


def get_playernick(log_file)
    # this is to get the nickname you call yourself in the game from pokerth
    puts "log_file = #{log_file}"
    db = SQLite3::Database.open log_file
    db.execute "PRAGMA journal_mode = WAL"
    stm = db.prepare "SELECT * FROM Player WHERE Seat='1' LIMIT 2" 
    rs = stm.execute
    rs.each do |row|
      #puts "row = #{row}"
      puts "row[2] = #{row[2]}"
      return row[2]
    end   
end

#puts "#{get_playernick(log_file)}"
#exit -1


def get_configs(full_account_log_file, log_file)
  config_hash = {"playernick"=>"notset", "account"=>"notset", "secreet"=>"notset", "currency"=>"CHP", "paymenturl"=>"test.stellar.org","stellarissuer"=>"gLanQde43yv8uyvDyn2Y8jn9C9EuDNb1HF", "accountserver"=>"test.surething.biz/player_list", "new"=>TRUE, "acc_pair"=>{"account"=>"notset","secret"=>"notset"}}
  begin    
    db = SQLite3::Database.open full_account_log_file
    db.execute "CREATE TABLE IF NOT EXISTS Configs(Id INTEGER PRIMARY KEY, 
        PlayerNick TEXT UNIQUE, AccountID TEXT, master_seed TEXT, Currency TEXT, PaymentURL TEXT,Stellar_Issuer TEXT,Account_serverURL TEXT)"
    
    c = db.execute( "SELECT count(*) FROM Configs ")
   
    #puts "c = #{c[0][0]}"
    exists = c[0][0]
    if exists == 0
       puts "got here not exist"
      playernick = get_playernick(log_file)
      puts "playernick = #{playernick}"
      acc_pair = create_new_account()
      config_hash["playernick"]=playernick
      config_hash["account"]=acc_pair["account"]
      config_hash["secreet"]=acc_pair["secreet"]
      config_hash["acc_pair"]=acc_pair
      db.execute "INSERT or REPLACE INTO Configs VALUES(NULL,'#{playernick}','#{acc_pair["account"]}','#{acc_pair["secret"]}','#{config_hash["currency"]}','#{config_hash["paymenturl"]}','#{config_hash["stellarissuer"]}', '#{config_hash["accountserver"]}')"
    else
      puts "got here does exist"
      db.execute "PRAGMA journal_mode = WAL"
      rs = db.execute "SELECT * FROM Configs " 
      rs.each do |row|
        puts "row = #{row}"
        puts "row[2] = #{row[2]}"
        config_hash["new"]=FALSE
        config_hash["playernick"]=row[1]
        config_hash["account"]=row[2]
        config_hash["secreet"]=row[3]
        config_hash["acc_pair"]={"account"=>row[2], "secret"=>row[3]} 
        config_hash["currency"]=row[4]  
        config_hash["paymenturl"]=row[5]
        config_hash["stellarissuer"]=row[6]
        config_hash["accountserver"]=row[7]     
      end   
    end

  rescue SQLite3::Exception => e 
    
    puts "Exception occurred in get_configs "
    puts e
    
  ensure
    db.close if db
  end
  db.close if db
  return config_hash
end

 #puts "#{get_configs(full_account_log_file, log_file)}"
 #exit -1

def update_account_log(full_account_log_file, log_file, playername,amount,gamenumber)
  #puts "playername = #{playername} amount #{amount}"
  amount = amount.round(2)
  begin    
    db = SQLite3::Database.open full_account_log_file
    db.execute "CREATE TABLE IF NOT EXISTS Players(Id INTEGER PRIMARY KEY, 
        Name TEXT UNIQUE, Ballance INT, AccountID TEXT, master_seed TEXT, AccBal INT, AccBalLast INT, AccDiff INT)"
    db.execute "CREATE TABLE IF NOT EXISTS Events(Id INTEGER PRIMARY KEY, 
        Name TEXT, Amount INT, GameID INT, Log_file TEXT, AccountID TEXT, Time TEXT)"

    c = db.execute( "SELECT count(*) FROM Players WHERE Name = 'Total_sent'")
    #puts "c = #{c[0][0]}"
    exists = c[0][0]
    if exists == 0

      new_pair = create_new_account_with_CHP_trust(acc_issuer_pair)
      
      db.execute "INSERT or REPLACE INTO Players VALUES(NULL,'Total_sent','#{amount}','#{new_pair["account"]}','#{new_pair["secret"]}',NULL, NULL,NULL)"
    else
      db.execute "UPDATE Players SET Ballance = Ballance + #{amount} WHERE Name = 'Total_sent'"
    end

    c = db.execute( "SELECT count(*) FROM Players WHERE Name = '#{playername}'")
    #puts "c = #{c[0][0]}"
    exists = c[0][0]
    if exists == 0
      acc_issuer_account = playername_to_accountID("Total_sent", full_account_log_file)
      acc_issuer_secret = playername_to_secret("Total_sent", full_account_log_file)
      acc_issuer_pair = {"account"=>acc_issuer_account, "secret"=>acc_issuer_secret}
      new_pair = create_new_account_with_CHP_trust(acc_issuer_pair)
      puts "new_pair = #{new_pair}"
      db.execute "INSERT or REPLACE INTO Players VALUES(NULL,'#{playername}','#{amount}','#{new_pair["account"]}','#{new_pair["secret"]}',NULL, NULL,NULL)"
    else
      db.execute "UPDATE Players SET Ballance = Ballance + #{amount} WHERE Name = '#{playername}'"
    end
    timestr = DateTime.now
    #puts "time = #{timestr}"
    accountID = playername_to_accountID(playername, full_account_log_file)
    db.execute("INSERT INTO Events VALUES(NULL,'#{playername}','#{amount}','#{gamenumber}','#{log_file}','#{accountID}', '#{timestr}')")   
    
  rescue SQLite3::Exception => e 
    
    puts "Exception occurred in update_account_log"
    puts e
    
  ensure
    db.close if db
  end
  db.close if db
end

#update_account_log(full_account_log_file,playername,amount,gamenumber)
#exit -1


def proc_exists(procname)
  Sys::ProcTable.ps.each { |ps|
    if ps.name.downcase == procname    
      return TRUE
    end
  }
  return FALSE
end


def get_start_cash(log_file, gamenumber)

 begin
    db = SQLite3::Database.open log_file
    db.execute "PRAGMA journal_mode = WAL"
    stm = db.prepare "SELECT * FROM Game WHERE UniqueGameID=#{gamenumber} LIMIT 2" 
    rs = stm.execute
    rs.each do |row|
      #puts "row = #{row}"
      #puts "row[2] = #{row[2]}"
      return row[2].to_i
    end   
  rescue SQLite3::Exception => e 
    
    puts "Exception occurred in get_start_cash"
    puts e
    
  ensure
    stm.close if stm
    db.close if db
  end
end

#start_cash = get_start_cash(log_file, gamenumber)
#puts "start_cash = #{start_cash}"
#exit -1

def find_last_log_file(dir_name)
  Dir.chdir dir_name
  filename = Dir.glob("*").max_by {|f| File.mtime(f)}
  puts "last log filename = #{filename}"
  return filename
end

#find_last_log_file(log_dir)
#exit -1

def check_db_lock( log_file )
  #puts "start check_db_lock"
  fail = FALSE
  begin
    db = SQLite3::Database.open log_file
    db.execute "PRAGMA journal_mode = WAL"
  rescue SQLite3::Exception => e 

    puts "Exception occurred in check_db_lock"
    puts e
    fail = TRUE
    sleep 5
  ensure   
    #db.close if db
  end
  #db.close if db
  #puts "exit check_db_lock"
  return db
end

#while TRUE do
#  check_db_lock(log_file)
#end
#exit -1

def find_max_game( log_file)
 
 begin
    #db = check_db_lock( log_file )
    db = SQLite3::Database.open log_file
    db.execute "PRAGMA journal_mode = WAL"
    stm = db.prepare "SELECT max(UniqueGameID) FROM Game LIMIT 1" 
    rs = stm.execute
    rs.each do |row|
      #puts "row = #{row}"
      #puts "row[1] = #{row[0]}"
      return row[0].to_i
    end   
  rescue SQLite3::Exception => e 
    
    puts "Exception occurred in find_max_game"
    puts e
    
  ensure
    stm.close if stm
    db.close if db
  end
  stm.close if stm
  db.close if db
end

#maxgame = find_max_game( log_file)
#puts "maxgame = #{maxgame}"

#exit -1

def find_max_hand_in_game (log_file, gamenumber)
  #puts "log_file in find_max_hand #{log_file}"
  
  begin
    #db = check_db_lock( log_file )
    db = SQLite3::Database.open log_file
    db.execute "PRAGMA journal_mode = WAL"
    #puts "db ok"
    stm = db.prepare "SELECT max(HandID) FROM Hand  WHERE UniqueGameID=#{gamenumber} LIMIT 1" 
    #puts "stm ok"
    rs = stm.execute
    #puts "rs ok"
    rs.each do |row|
      #puts "row = #{row}"
      #puts "row[0] = #{row[0]}"
      return row[0].to_i
    end   
  rescue SQLite3::Exception => e 
    
    puts "Exception occurred in find_max_hand_in_game"
    puts e
    
  ensure
    stm.close if stm
    db.close if db
  end
  stm.close if stm
  db.close if db
end

#maxhand = find_max_hand_in_game(log_file, gamenumber)
#puts "maxhand = #{maxhand}"
#exit -1

def seatnumber_to_player( seat, gamenumber, log_file)

  begin
    db = SQLite3::Database.open log_file
    db.execute "PRAGMA journal_mode = WAL"
    stm = db.prepare "SELECT * FROM Player WHERE UniqueGameID=#{gamenumber} LIMIT 15" 
    rs = stm.execute
    rs.each do |row|
      #puts "row = #{row}"
      if row[1].to_i == seat.to_i
        return row[2]
      end
    end
  rescue SQLite3::Exception => e 
    
    puts "Exception occurred"
    puts e
    
  ensure
    stm.close if stm
    db.close if db
  end
end

def send_player_chips( seat, amount, gamenumber, log_file,account_dir)
  amount = amount.round(2)
  account_file = account_dir+"account_log.pdb"
  playername = seatnumber_to_player( seat, gamenumber, log_file)
  puts "send player #{playername} in seat #{seat}  #{amount} amount of chips"
  update_account_log(account_file,log_file,playername,amount,gamenumber)
  # to enable sending stellar set bellow if to TRUE
  if TRUE
    config = get_configs(account_file, log_file)
    send_to_accountid = playername_to_accountID(playername, account_file)
    from_acc_accountid = config["account"]
    from_acc_secret = config["secret"]
    from_issuer_pair = {"account"=>from_acc_accountid, "secret"=>from_acc_secret}
    #send_CHP(from_issuer_pair, send_to_accountid, amount)
    send_currency(from_issuer_pair, send_to_accountid, amount,config["currency"])
    sleep 12
    stellar = Payment.new
    stellar.set_account(send_to_accountid)
    data = stellar.account_lines
    puts "after deposit lines #{data}"
  end  
end
#name = seatnumber_to_player(8,5,log_file)
#puts "name = #{name}"
#send_player_chips(8,100,5,log_file)
#exit -1


def send_winner_hand_chips(log_file, gamenumber, handID, start_cash,account_dir)
if handID <= 0 
  puts "handID is zero or less exiting send_winner... "
  return 
end
puts "log_file = #{log_file}"
seat_diff = [0,0,0,0,0,0,0,0,0,0]
winner = [FALSE,FALSE,FALSE,FALSE,FALSE,FALSE,FALSE,FALSE,FALSE,FALSE]
last_winner_seat = 0
last_winner_send = 0
begin
    
    db = SQLite3::Database.open log_file
    db.execute "PRAGMA journal_mode = WAL"
    db.results_as_hash = true
    if handID == 1
      starthand = handID
    else 
      starthand = handID - 1
    end
    puts "starthand = #{starthand}"
    stm = db.prepare "SELECT * FROM Hand WHERE UniqueGameID=#{gamenumber} AND HandID >= #{starthand} LIMIT 2" 
    
    rs = stm.execute 
    
    seat_1_cash_last=start_cash
    seat_2_cash_last=start_cash
    seat_3_cash_last=start_cash
    seat_4_cash_last=start_cash
    seat_5_cash_last=start_cash
    seat_6_cash_last=start_cash
    seat_7_cash_last=start_cash
    seat_8_cash_last=start_cash
    seat_9_cash_last=start_cash
    seat_10_cash_last=start_cash
    total_loss_seat_1=0
    not_first_row = FALSE
    rs.each do |row|
        total_loss_seat_1 = row['Seat_1_Cash'].to_i - start_cash
            
        seat_diff[1] = row['Seat_1_Cash'].to_i - seat_1_cash_last
        seat_diff[2] = row['Seat_2_Cash'].to_i - seat_2_cash_last
        seat_diff[3] = row['Seat_3_Cash'].to_i - seat_3_cash_last
        seat_diff[4] = row['Seat_4_Cash'].to_i - seat_4_cash_last
        seat_diff[5] = row['Seat_5_Cash'].to_i - seat_5_cash_last
        seat_diff[6] = row['Seat_6_Cash'].to_i - seat_6_cash_last
        seat_diff[7] = row['Seat_7_Cash'].to_i - seat_7_cash_last
        seat_diff[8] = row['Seat_8_Cash'].to_i - seat_8_cash_last
        seat_diff[9] = row['Seat_9_Cash'].to_i - seat_9_cash_last
        seat_diff[10] = row['Seat_10_Cash'].to_i - seat_10_cash_last
        win_count=0
        puts "seat_diff[1] = #{seat_diff[1].to_i}"
        puts "handID = #{handID}  not_first_row = #{not_first_row}"
        #puts "(not_first_row || handID == 1) = #{(not_first_row || handID == 1)}"
       
        if (seat_diff[1].to_i < 0) && (not_first_row || handID == 1)
          
          #puts "here" 
          #puts "seat_diff #{seat_diff}"
          seat=0
          winner = [FALSE,FALSE,FALSE,FALSE,FALSE,FALSE,FALSE,FALSE,FALSE,FALSE,FALSE]
          total_pot_winnings = 0
          seat_diff.each do |x|
            
            #puts "seat_diff[#{seat}] = #{seat_diff[seat]}"
            if x > 0
              winner[seat]=TRUE
              win_count += 1
              total_pot_winnings = total_pot_winnings + x
              #puts "here win_count #{win_count}  winner seat #{seat} wins #{x} chips"
            end
            seat += 1
          end
          puts "win_count = #{win_count}"
          seat=0
          winner.each do |win|        
            #puts "seat = #{seat}"
            if win == TRUE
              multiple_of_pot = seat_diff[seat].to_f / total_pot_winnings.to_f
              send_chip_ammount = seat_diff[1].to_f * multiple_of_pot.to_f * -1
              puts "multiple_of_pot = #{multiple_of_pot}"
              #puts "send seat #{seat}  #{seat_diff[1]/win_count} chips"
              winners_seat = seat
              #last_winner_send = seat_diff[1]/win_count
              send_player_chips( winners_seat, send_chip_ammount, gamenumber, log_file,account_dir)
              #return TRUE
            end
            seat +=1
          end
        end
       not_first_row = TRUE
       # puts "seat_1_cash_last = #{seat_1_cash_last.to_i}"
       # puts "seat_1_Cash =  #{row['Seat_1_Cash'].to_i} "
       # puts " seat_diff[1]= #{seat_diff[1]}"        
       # puts " total_loss_seat_1 = #{total_loss_seat_1}"

        seat_1_cash_last=row['Seat_1_Cash'].to_i
        seat_2_cash_last=row['Seat_2_Cash'].to_i
        seat_3_cash_last=row['Seat_3_Cash'].to_i
        seat_4_cash_last=row['Seat_4_Cash'].to_i
        seat_5_cash_last=row['Seat_5_Cash'].to_i
        seat_6_cash_last=row['Seat_6_Cash'].to_i
        seat_7_cash_last=row['Seat_7_Cash'].to_i
        seat_8_cash_last=row['Seat_8_Cash'].to_i
        seat_9_cash_last=row['Seat_9_Cash'].to_i
        seat_10_cash_last=row['Seat_10_Cash'].to_i
        puts " seat_1_cash_last = #{seat_1_cash_last}"
    end
           
rescue SQLite3::Exception => e     
    puts "Exception occurred"
    puts e    
ensure
    stm.close if stm
    db.close if db
end
  puts "exit send_winner..."
  #return FALSE
end  #end function 

#send_winner_hand_chips(log_file, gamenumber, handID, start_cash, account_dir)
#exit -1

def run_loop(log_dir,account_dir)
  log_file = find_last_log_file(log_dir)
  full_log_file = log_dir+log_file
  puts "full_log_file = #{full_log_file}"
  puts "log_file: #{log_file}"
  gamenumber = find_max_game( log_file)
  #start_cash = get_start_cash(log_file, gamenumber)
  #puts "start_cash = #{start_cash}"
  maxhand = find_max_hand_in_game(log_file, gamenumber)
  # wait for new game to start or new log file to be created
  while TRUE  do    
    newgamenumber = find_max_game( log_file)
    #newlog_file = find_last_log_file(log_dir)
    puts "newgamenumber = #{newgamenumber}"
    #puts "newlog_file = #{newlog_file}"
    #if newgamenumber != gamenumber || newlog_file != log_file
    if newgamenumber != gamenumber 
      break
    end
    sleep(5)
  end
  puts "new game started"  
  gamenumber = find_max_game( log_file)
  start_cash = get_start_cash(log_file, gamenumber)
  while TRUE  do
    puts "gamenumber = #{gamenumber}"
    puts "maxhand = #{maxhand}"
    newmaxhand = find_max_hand_in_game(log_file, gamenumber)
    if newmaxhand != maxhand
      # do check
      puts "change detected"
      send_winner_hand_chips(log_file, gamenumber, newmaxhand, start_cash,account_dir)
      maxhand = newmaxhand
    end
    newgamenumber = find_max_game( log_file)
    if newgamenumber != gamenumber
      break
    end
    if proc_exists("pokerth") == FALSE
      puts "pokerth no longer running will exit now"
      break
    end
    sleep(5)
  end

end

log_file = find_last_log_file(log_dir)
full_log_file = log_dir+log_file
conf = get_configs(full_account_log_file, full_log_file)
puts "#{conf}"


update_players_accounts(full_account_log_file, conf["playernick"],conf["account"])
  
run_loop(log_dir,account_dir)

